//
//  OnboardingView.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 3/1/25.
//
import SwiftUI

extension Color {
    static let primaryBluePurple = Color(hex: "#5771FF")
}
struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var hasAcceptedTerms = false
    @State private var showTermsView = false

    let pages = [
        OnboardingPage(image: "newimg1", title: "Track Transactions", description: "Log and categorize your expenses with ease."),
        OnboardingPage(image: "newimg2", title: "Manage Recurring Transactions", description: "Set up automatic tracking for your regular expenses."),
        OnboardingPage(image: "newimg3", title: "Financial Summary & Trends", description: "View insights and trends with dynamic summary cards."),
        OnboardingPage(image: "newimg4", title: "Set & Track Financial Goals", description: "Plan ahead and monitor your financial progress."),
        OnboardingPage(image: "newimg5", title: "Visualize with Dynamic Charts", description: "Analyze your financial health through interactive graphs."),
        OnboardingPage(image: "tosimg", title: "Privacy & Terms", description: "Read our privacy policy and terms before getting started.")
    ]
    
    var onComplete: () -> Void // Completion handler to dismiss onboarding

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack {
                    Spacer()
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            VStack {
                                Image(pages[index].image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 350)
                                    .padding(.bottom, 20)

                                Text(pages[index].title)
                                    .font(.largeTitle.bold())
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)

                                Text(pages[index].description)
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .padding(.top, 10)

                                if index == pages.count - 1 {
                                    Button(action: {
                                        showTermsView = true
                                    }) {
                                        Text("Read Terms & Privacy")
                                            .font(.headline)
                                            .foregroundColor(bluePurpleColor)
                                            .padding(.top, 10)
                                    }
                                }
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentPage)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)

                            Capsule()
                                .fill(bluePurpleColor)
                                .frame(width: (geometry.size.width / CGFloat(pages.count)) * CGFloat(currentPage + 1), height: 6)
                                .animation(.easeInOut(duration: 0.3), value: currentPage)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)

                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else if hasAcceptedTerms {
                            onComplete() // Dismiss onboarding
                        }
                    }) {
                        Text(currentPage == pages.count - 1 ? (hasAcceptedTerms ? "Get Started" : "Agree & Continue First") : "Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(hasAcceptedTerms || currentPage < pages.count - 1 ? bluePurpleColor : Color.gray)
                            .cornerRadius(12)
                            .padding(.horizontal, 40)
                            .shadow(radius: 5)
                    }
                    .padding(.bottom, 40)
                    .disabled(currentPage == pages.count - 1 && !hasAcceptedTerms)
                }
            }
            .fullScreenCover(isPresented: $showTermsView) {
                TermsView(hasAcceptedTerms: $hasAcceptedTerms)
            }
        }
    }
}

struct OnboardingPage {
    let image: String
    let title: String
    let description: String
}


import SwiftUI

struct TermsView: View {
    @Binding var hasAcceptedTerms: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Title
                    Text("Privacy Policy & Terms")
                        .font(.largeTitle.bold())
                        .padding(.bottom, 10)
                        .padding(.horizontal)

                    Divider()

                    // Privacy Policy Section
                    Text("Privacy Policy")
                        .font(.title.bold())
                        .padding(.top, 5)
                        .padding(.horizontal)
                    
                    Text("""
                    Your privacy is our top priority. We are committed to providing a secure and private experience while using this application. To ensure complete transparency, we want to make it clear that this app **does not collect, store, or share any personal data.**
                    """)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                    Text("**What This Means for You:**")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• No personal information, such as your name, email, or financial data, is stored or transmitted outside your device.")
                        Text("• All transactions, budgets, and financial insights remain strictly on your device and are never uploaded to any servers or cloud storage.")
                        Text("• We do not use third-party analytics tools, tracking mechanisms, or advertising networks that collect user behavior or data.")
                        Text("• There are no hidden data-sharing agreements with any third-party services, meaning your financial information stays completely private.")
                    }
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                    Text("**How Your Data is Handled:**")
                        .font(.headline)
                        .padding(.top, 5)
                        .padding(.horizontal)

                    Text("""
                    Since this app does not connect to the internet for data storage, all financial information is kept **locally** on your device. This means your data is only accessible to you and will not be shared with developers, companies, or third parties.

                    However, please note that if you delete the app, your data may be permanently erased, as we do not store backup copies. Be sure to manually export or save any important information before removing the app.
                    """)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                    Divider()

                    // Terms of Service Section
                    Text("Terms of Service")
                        .font(.title.bold())
                        .padding(.top, 5)
                        .padding(.horizontal)

                    Text("**1. No Warranties or Guarantees**")
                        .font(.headline)
                        .padding(.horizontal)

                    Text("""
                    This app is provided **as-is**, without any warranties of any kind. While we strive to ensure a smooth and reliable experience, we do not guarantee that the app will always function flawlessly, be error-free, or meet every user’s financial needs.
                    """)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                    Text("**2. User Responsibility**")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• You are solely responsible for how you use this app.")
                        Text("• Any financial decisions, budgeting plans, or expense tracking performed within the app are entirely your responsibility.")
                        Text("• We are not liable for any financial loss, budgeting miscalculations, or errors that result from using this app.")
                    }
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                    Text("**3. No Financial Advice**")
                        .font(.headline)
                        .padding(.horizontal)

                    Text("""
                    This app is designed to help you track and manage your finances, but it **does not provide professional financial advice**. Any insights or trends displayed within the app are for informational purposes only and should not be considered financial, legal, or tax advice.

                    If you need professional financial assistance, we strongly recommend consulting a licensed financial advisor or accountant.
                    """)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                    Text("**4. No Online Services or Account Creation**")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• This app does not require you to create an account, sign in, or connect to any online services.")
                        Text("• Since there is no internet connectivity within the app, no data is uploaded, and your activity remains private.")
                    }
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                    Text("**5. Limitation of Liability**")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• The developers of this application will not be held responsible for any issues, errors, or losses that arise from using the app.")
                        Text("• You assume full responsibility for any financial tracking or budgeting decisions you make.")
                        Text("• In no event shall the creators of this app be held liable for damages, including but not limited to financial losses, data loss, or unforeseen consequences related to the app’s use.")
                    }
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                    Spacer()

                    // Agree & Continue Button
                    Button(action: {
                        hasAcceptedTerms = true
                        dismiss()
                    }) {
                        Text("Agree & Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bluePurpleColor)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .shadow(radius: 5)
                    }
                    .padding(.bottom, 40)
                }
                .padding(.top)
            }
            .navigationBarTitle("Terms & Privacy", displayMode: .inline)
        }
    }
}

struct TermsView_Previews: PreviewProvider {
    static var previews: some View {
        TermsView(hasAcceptedTerms: .constant(false))
    }
}
