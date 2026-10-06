import Foundation

/// Reads and writes snippets as XML in the layout Clipy (ClipMenu's successor)
/// uses for import and export:
///
///     <folders>
///       <folder>
///         <title>Folder</title>
///         <snippets>
///           <snippet><title>Name</title><content>Text</content></snippet>
///         </snippets>
///       </folder>
///     </folders>
public enum SnippetXML {
    public enum ParseError: Error, Equatable {
        case notSnippetXML
    }

    public static func export(_ folders: [SnippetFolder]) -> Data {
        let root = XMLElement(name: "folders")
        for folder in folders {
            let folderElement = XMLElement(name: "folder")
            folderElement.addChild(XMLElement(name: "title", stringValue: folder.title))
            let snippetsElement = XMLElement(name: "snippets")
            for snippet in folder.snippets {
                let snippetElement = XMLElement(name: "snippet")
                snippetElement.addChild(XMLElement(name: "title", stringValue: snippet.title))
                snippetElement.addChild(XMLElement(name: "content", stringValue: snippet.content))
                snippetsElement.addChild(snippetElement)
            }
            folderElement.addChild(snippetsElement)
            root.addChild(folderElement)
        }
        let document = XMLDocument(rootElement: root)
        document.version = "1.0"
        document.characterEncoding = "UTF-8"
        return document.xmlData(options: [.nodePrettyPrint])
    }

    public static func parse(_ data: Data) throws -> [SnippetFolder] {
        let document = try XMLDocument(data: data, options: [.nodePreserveWhitespace])
        guard let root = document.rootElement(), root.name == "folders" else {
            throw ParseError.notSnippetXML
        }
        return root.elements(forName: "folder").map { folderElement in
            let snippets = folderElement.elements(forName: "snippets").first?
                .elements(forName: "snippet")
                .map { snippetElement in
                    Snippet(
                        title: text(of: "title", in: snippetElement),
                        content: text(of: "content", in: snippetElement)
                    )
                } ?? []
            return SnippetFolder(title: text(of: "title", in: folderElement), snippets: snippets)
        }
    }

    private static func text(of childName: String, in element: XMLElement) -> String {
        element.elements(forName: childName).first?.stringValue ?? ""
    }
}
