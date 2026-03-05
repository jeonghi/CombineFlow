import ProjectDescription

let project = Project(
    name: "CombineFlow",
    options: .options(automaticSchemesOptions: .enabled()),
    targets: [
        .target(
            name: "CombineFlow",
            destinations: .iOS,
            product: .framework,
            bundleId: "io.combineflow.CombineFlow",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            buildableFolders: ["Sources/CombineFlow"],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0"
            ])
        )
    ]
)
