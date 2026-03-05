import ProjectDescription

let project = Project(
    name: "CombineFlowExample",
    options: .options(automaticSchemesOptions: .enabled()),
    targets: [
        .target(
            name: "CombineFlowExample",
            destinations: .iOS,
            product: .app,
            bundleId: "io.combineflow.Example",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "CFBundleDisplayName": "CombineFlowExample",
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false,
                    "UISceneConfigurations": [
                        "UIWindowSceneSessionRoleApplication": [
                            [
                                "UISceneConfigurationName": "Default Configuration",
                                "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate"
                            ]
                        ]
                    ]
                ]
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                .project(target: "CombineFlow", path: "../CombineFlow")
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0"
            ])
        )
    ]
)
