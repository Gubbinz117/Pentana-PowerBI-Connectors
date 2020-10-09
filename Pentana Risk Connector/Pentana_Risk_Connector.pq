// This file contains your Data Connector logic
section Pentana_Risk_Connector;

[DataSource.Kind="Pentana_Risk_Connector", Publish="Pentana_Risk_Connector.Publish"]
shared Pentana_Risk_Connector.Contents = (optional message as text) =>
    let
        return = rootRisks()
    in
        return;

// Data Source Kind description
Pentana_Risk_Connector = [
    Authentication = [
                UsernamePassword = 
                            [
			                    UsernameLabel = "client_username#client_password (API Username and API Password seperated by '#')",
                                PasswordLabel = "client_secret"
                            ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Pentana_Risk_Connector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Pentana_Risk_Connector.Icons,
    SourceTypeImage = Pentana_Risk_Connector.Icons
];

Pentana_Risk_Connector.Icons = [
    Icon16 = { Extension.Contents("Pentana_Risk_Connector16.png"), Extension.Contents("Pentana_Risk_Connector20.png"), Extension.Contents("Pentana_Risk_Connector24.png"), Extension.Contents("Pentana_Risk_Connector32.png") },
    Icon32 = { Extension.Contents("Pentana_Risk_Connector32.png"), Extension.Contents("Pentana_Risk_Connector40.png"), Extension.Contents("Pentana_Risk_Connector48.png"), Extension.Contents("Pentana_Risk_Connector64.png") }
];

//Authorization Details
//Splits password out from the username submitted as part of authentication
client_password = 
                    List.Last(
                        Text.Split(
                            Extension.CurrentCredential()[Username],
                                "#"
                        )
                    );
//Splits username out from the username submitted as part of authentication
client_username = 
                    List.First(
                        Text.Split(
                            Extension.CurrentCredential()[Username],
                                "#"
                        )
                    );
//Retrieves client_secret information from the password field submitted as part of authentication
client_secret = Extension.CurrentCredential()[Password];
//uris
token_uri = "https://stirling.pentanarpm.uk/cpmweb/oauth/token";
rootrisks_uri = "https://stirling.pentanarpm.uk/cpmweb/api/risks/roots";
//Authorization Content
auth_body = "{ ""grant_type"":""password"",""username"":"""&client_username&""",""password"":"""&client_password&"""}";
auth_parsedbody = Json.Document(auth_body);
auth_content = Uri.BuildQueryString(auth_parsedbody);
auth_requestheaders = [
    #"Content-Type" = "application/x-www-form-urlencoded",
    #"Authorization" = "Basic "&client_secret,
    #"Accept"  = "application/json"
];
//Get Token
Token = 
        "Bearer "&
                    Json.Document(
                        Web.Contents(
                            token_uri,
                                [
                                    Headers = auth_requestheaders,
                                    Content = Text.ToBinary(auth_content),
                                    //IsRetry stops unwanted caching
                                    IsRetry = true
                                ]
                        )
                    )[access_token];
//Set first level navigation table
rootRisks = () as table =>
    let
        //http request for all root level risks
        GetRoot = 
            Json.Document(  
                Web.Contents(
                    rootrisks_uri,
                    [
                    Headers=[Authorization=Token],
                    //IsRetry stops unwanted caching
                    IsRetry=true                
                    ]
                )
            ),
        #"Converted to Table" = 
            Table.FromList(
                GetRoot,
                Splitter.SplitByNothing(),
                null,
                null,
                ExtraValues.Error
            ),
        //Expand results to show id, code, active status and links to further risks data then filter out deactivated risks and null values
        #"Expanded Column1" = 
            Table.ExpandRecordColumn(
                #"Converted to Table",
                "Column1",
                { "id", "title", "active"},
                { "id", "title", "active"}
            ),
        #"Filtered Rows" = 
            Table.SelectRows(
                #"Expanded Column1",
                each ([active] = true)
            ),
        #"Removed Columns" = 
            Table.RemoveColumns(
                #"Filtered Rows",
                {"active"}
            ),
        //Add nav columns
        #"Add itemKind" = 
            Table.AddColumn(
                #"Removed Columns",
                "itemKind",
                each "Table"
            ),
        #"Add itemName" = 
            Table.AddColumn(
                #"Add itemKind",
                "itemName",
                each "Table"
            ),
        //Get Subrisks of Root including any subrisks of these as layered navigation tables where the full risk detail is only expanded for the leaf level
        GetNextLevelRisks =
            Table.AddColumn(
                #"Add itemName",
                "data",
                each 
                    GetSubRisks(Number.ToText([id]))
            ),
        #"Add isLeaf" = 
            Table.AddColumn(
                GetNextLevelRisks,
                "isLeaf",
                each
                    false
            ),
        CreateNav = Table.ToNavigationTable(#"Add isLeaf",{"id"},"title","data","itemKind","itemName","isLeaf")
    in
        CreateNav;

GetSubRisks = (id as text) =>
    let
        GetSubs = 
            Table.FromList(
                Json.Document(
                Web.Contents(
                    "https://stirling.pentanarpm.uk/cpmweb/api/risks/"&id&"/subrisks",
                    [
                       Headers=[Authorization=Token],
                       //IsRetry stops unwanted caching
                       IsRetry=true                
                    ]
                )
            ),
                Splitter.SplitByNothing(),
                null,
                null,
                ExtraValues.Error
            ),
        ExpandSubsRecord =
            if Table.RowCount(GetSubs) = 0
            then GetSubs
            else
            Table.ExpandRecordColumn(
                GetSubs, "Column1", 
                {"id", "code", "title", "active"}, 
                {"id", "code", "title", "active"}
            ),
        AddData = 
        if Table.RowCount(ExpandSubsRecord) = 0
        then GetLeafRisk(id)
        else
            Table.AddColumn(
                ExpandSubsRecord,
                "data",
                each GetSubRisks(Number.ToText([id]))
                ),
        #"Add itemKind" = 
        if Table.RowCount(ExpandSubsRecord) = 0
        then AddData
        else
            Table.AddColumn(
                AddData,
                "itemKind",
                each "Table"
            ),
        #"Add itemName" = 
        if Table.RowCount(ExpandSubsRecord) = 0
        then AddData
        else
            Table.AddColumn(
                #"Add itemKind",
                "itemName",
                each "Table"
            ),
        #"Add isLeaf" = 
         if Table.RowCount(ExpandSubsRecord) = 0
        then AddData
        else
            Table.AddColumn(
                #"Add itemName",
                "isLeaf",
                each false
            ),
        FinaliseNavTable = if Table.RowCount(ExpandSubsRecord) = 0
        then AddData
        else Table.ToNavigationTable(#"Add isLeaf",{"id"},"title","data","itemKind","itemName","isLeaf")
    in
        FinaliseNavTable;

GetLeafRisk = (id as text) =>
    let
        RiskDetail = Json.Document(
                            Web.Contents(
                                "https://stirling.pentanarpm.uk/cpmweb/api/risks/"&id,
                                [
                                    Headers=[Authorization=Token],
                                    //IsRetry stops unwanted caching
                                    IsRetry=true                
                                ]
                            )
                            ),
        InternalControls = Json.Document(
                            Web.Contents(
                                "https://stirling.pentanarpm.uk/cpmweb/api/risks/"&id&"/internalControls",
                                [
                                    Headers=[Authorization=Token],
                                    //IsRetry stops unwanted caching
                                    IsRetry=true                
                                ]
                            )
                            ),
        Assessments = Json.Document(
                            Web.Contents(
                                "https://stirling.pentanarpm.uk/cpmweb/api/risks/"&id&"/assessments",
                                [
                                    Headers=[Authorization=Token],
                                    //IsRetry stops unwanted caching
                                    IsRetry=true                
                                ]
                            )
                            ),
        Ownership = Json.Document(
                            Web.Contents(
                                "https://stirling.pentanarpm.uk/cpmweb/api/risks/"&id&"/owners",
                                [
                                    Headers=[Authorization=Token],
                                    //IsRetry stops unwanted caching
                                    IsRetry=true                
                                ]
                            )
                            ),
        Actions = Record.Field(
                        Json.Document(
                            Web.Contents(
                                "https://stirling.pentanarpm.uk/cpmweb/api/risks/"&id&"/links",
                                [
                                    Headers=[Authorization=Token],
                                    //IsRetry stops unwanted caching
                                    IsRetry=true                
                                ]
                            ),
                            "linkedActions"
                        )
                    ),
        Risk = [
                    RiskDetail = RiskDetail,
                    InternalControls = InternalControls,
                    Assessments = Assessments,
                    Ownership = Ownership,
                    Actions = Actions
                ],
        RiskTable = Record.ToTable(Risk),
        LeafTable = Table.Pivot(RiskTable, List.Distinct(RiskTable[Name]), "Name", "Value"),
        CreateRiskRecordColumn = 
            Table.AddColumn(
                LeafTable,
                "data",
                each [
                        RiskDetail = [RiskDetail],
                        Internal Controls = [InternalControls],
                        Assessments = [Assessments],
                        Ownership = [Ownership],
                        Actions = [Actions]
                     ]
            ),
        ExtractTitle = Table.ExpandRecordColumn(CreateRiskRecordColumn, "RiskDetail", {"title"}, {"RiskDetail.title"}),
        RemoveExcessColumns = Table.RemoveColumns(ExtractTitle,{"InternalControls", "Assessments", "Ownership", "Actions"}),
        #"Add itemKind" = 
            Table.AddColumn(
                RemoveExcessColumns,
                "itemKind",
                each "Table"
            ),
        #"Add itemName" = 
            Table.AddColumn(
                #"Add itemKind",
                "itemName",
                each "Table"
            ),
        #"Add id" = 
            Table.AddColumn(
                #"Add itemName",
                "id",
                each id
            ),
        #"Add isLeaf" = 
            Table.AddColumn(
                #"Add id",
                "isLeaf",
                each true
            ),
        LeafTable_Nav = Table.ToNavigationTable(#"Add isLeaf",{"id"},"title","data","itemKind","itemName","isLeaf")
    in
        LeafTable_Nav;

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;
