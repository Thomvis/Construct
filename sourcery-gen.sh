sourcery --sources App/App --exclude-sources App/App/Sourcery --sources Sources/Helpers --templates SourceryTemplates/NavigationNode.stencil --output App/App/Sourcery

sourcery --sources Sources/Compendium --exclude-sources Sources/Compendium/SourceryOutput --templates SourceryTemplates/XMLDocumentElement.stencil --output Sources/Compendium/SourceryOutput

sourcery --sources Sources/GameModels --sources Sources/Helpers --exclude-sources Sources/GameModels/SourceryOutput --templates SourceryTemplates/ParseableGameModels.stencil --output Sources/GameModels/SourceryOutput

sourcery --sources Sources/Persistence --exclude-sources Sources/Persistence/SourceryOutput --templates SourceryTemplates/KeyValueStoreEntityDecoding.stencil --output Sources/Persistence/SourceryOutput