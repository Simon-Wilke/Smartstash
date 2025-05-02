//
//  AllTransactionsView.swift
//  SimpleBudgetManager
//
//  Created by Simon Wilke on 12/15/24.
//
import SwiftUI

struct AllTransactionsView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var isLoading = false
    @Environment(\.colorScheme) var colorScheme

    // Filtered transactions
    var filteredTransactions: [Transaction] {
        if searchText.isEmpty {
            return viewModel.transactions.sorted(by: { $0.date > $1.date })
        } else {
            return viewModel.transactions.filter { transaction in
                transaction.category.lowercased().contains(searchText.lowercased()) || transaction.notes?.lowercased().contains(searchText.lowercased()) ?? false
            }.sorted(by: { $0.date > $1.date })
        }
    }

    private var groupedTransactions: [Date: [Transaction]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Search bar at the top
                    CustomSearchBar(text: $searchText)
                        .padding(.top, 0)
                        .padding(.leading, -10)

                    if filteredTransactions.isEmpty {
                        // Placeholder message when no results are found
                        Text("No results found")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .gray)
                            .padding(.top, 50)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                            // Loop through grouped transactions
                            ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                                Section(
                                    header: CustomHeaderView(title: formattedDateHeader(for: date))
                                ) {
                                    ForEach(groupedTransactions[date] ?? []) { transaction in
                                        TransactionRowView(transaction: transaction)
                                            .padding(.vertical, 8)
                                    }
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                        .padding(.horizontal, 15)
                    }
                }
            }
            .navigationTitle("All Transactions")
            .navigationBarTitleDisplayMode(.inline)  // Ensures the title is inline
            .navigationBarItems(trailing: Button(action: {
                isPresented = false // Close the sheet
            }) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            })
            .navigationBarHidden(false)  // Explicitly ensuring the navigation bar is not hidden
            .onAppear {
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isLoading = false
                }
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }

    private func formattedDateHeader(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
struct CustomHeaderView: View {
    var title: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(title)
            .font(.headline).fontWeight(.bold)
            .foregroundColor(colorScheme == .dark ? .white : .primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 0) // Adjust horizontal padding for desired width
            .background(colorScheme == .dark ? Color.black : Color.white.opacity(0.7))
            .cornerRadius(0)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(width: 300, height: 60, alignment: .leading) // Fixed width and height for more control
    }
}

struct CustomSearchBar: View {
    @Binding var text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(colorScheme == .dark ? .white : .gray)
                .padding(.leading, 16)
            
            TextField("Search Transactions...", text: $text)
                .padding(12)
                .font(.body)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(colorScheme == .dark ? .white : .gray)
                }
                .padding(.trailing, 16)
            }
        }
        .padding(8)
        .background(colorScheme == .dark ? Color.black : Color.white) // Background adapts to dark mode
        .cornerRadius(20)
        .padding(.horizontal, 16)
        .padding(.leading, 60)
        .padding(.trailing, 40)
    }
}
