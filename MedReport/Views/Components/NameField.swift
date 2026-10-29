import SwiftUI

/// A text field with tappable suggestion rows under it.
struct NameField: View {
    @Binding var text: String
    let suggestions: [String]

    init(text: Binding<String>, suggestions: [String]) {
        _text = text
        self.suggestions = suggestions
    }

    var body: some View {
        TextField("For whom", text: $text)
            .textInputAutocapitalization(.words)
        ForEach(suggestions, id: \.self) { name in
            Button(name) { text = name }
                .foregroundStyle(.secondary)
                .frame(minHeight: 44, alignment: .leading)
        }
    }
}
