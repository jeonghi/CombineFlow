import ProjectDescription

let project = Project(
    name: "CombineFlowExample",
    options: .options(automaticSchemesOptions: .enabled()),
    packages: [
        .remote(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            requirement: .upToNextMajor(from: "1.10.0")
        )
    ],
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
            buildableFolders: ["Sources"],
            dependencies: [
                .project(target: "CombineFlow", path: "../CombineFlow"),
                .package(product: "ComposableArchitecture")
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0"
            ])
        )
    ]
)
