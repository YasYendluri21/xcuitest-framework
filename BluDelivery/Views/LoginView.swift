import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: Session
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sign in")
                .font(.largeTitle.bold())

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .accessibilityIdentifier(A11y.Login.email)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(A11y.Login.password)

            if let error = session.loginError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .accessibilityIdentifier(A11y.Login.error)
            }

            Button {
                Task { await session.signIn(email: email, password: password) }
            } label: {
                HStack {
                    if session.isAuthenticating {
                        ProgressView().accessibilityIdentifier(A11y.Login.spinner)
                    }
                    Text(session.isAuthenticating ? "Signing in…" : "Sign in")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(session.isAuthenticating)
            .accessibilityIdentifier(A11y.Login.submit)

            Spacer()
        }
        .padding(24)
    }
}
