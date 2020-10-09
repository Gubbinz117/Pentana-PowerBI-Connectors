// This file contains your Data Connector logic
section Pentana_Risk_Connector;

[DataSource.Kind="Pentana_Risk_Connector", Publish="Pentana_Risk_Connector.Publish"]
shared Pentana_Risk_Connector.Contents = (optional message as text) =>
    let
        _message = if (message <> null) then message else "(no message)",
        a = "Hello from Pentana_Risk_Connector: " & _message
    in
        a;

// Data Source Kind description
Pentana_Risk_Connector = [
    Authentication = [
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Implicit = []
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
