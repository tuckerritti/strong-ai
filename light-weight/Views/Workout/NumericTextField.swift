import SwiftUI

struct NumericTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.textAlignment = .center
        field.font = .systemFont(ofSize: 14, weight: .medium)
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Done", style: .done, target: field, action: #selector(UIResponder.resignFirstResponder)),
        ]
        field.inputAccessoryView = toolbar

        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text {
            field.text = text
        }
        if field.placeholder != placeholder {
            field.placeholder = placeholder
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let range = Range(range, in: current) else { return false }
            let updated = current.replacingCharacters(in: range, with: string)
            text.wrappedValue = updated
            return true
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
