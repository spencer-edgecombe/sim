//

import SwiftUI

struct ScrollViewAtTopPreferenceKey: PreferenceKey {
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
    
    static var defaultValue: Bool = true
}

class ScrollAtTop {
    var scrollAtTop: Bool = true
}

struct TopOfScrollView: View {
    @Binding var scrollAtTop: Bool
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 1)

            .onScrollVisibilityChange(threshold: 0.1) { visible in
                print("Scroll visibility changed: \(visible)")
                scrollAtTop = visible
            }
            .preference(key: ScrollViewAtTopPreferenceKey.self, value: scrollAtTop)
    }
}

struct NavBar: ToolbarContent {
    @State private var scrollAtTop: Bool = true
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Group {
//                if scrollAtTop {
                Text(scrollAtTop ? "Title" : "Toot")
                        .font(.title)
                        .id(scrollAtTop)
//                } else {
//                    EmptyView()
//                }

            }
            .fixedSize()
                .onPreferenceChange(ScrollViewAtTopPreferenceKey.self) { value in
                    scrollAtTop = value
                }
        }

        .sharedBackgroundVisibility(.hidden)
    }
}

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @State private var scrollAtTop: Bool = true
    @State private var presented: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $selectedTab) {
            TabSection {
                Tab(value: 0) {
                    NavigationStack {
                        List {
                                VStack {
                                    TopOfScrollView(scrollAtTop: $scrollAtTop)
                                    Text("Yas")
                                }
                                ForEach(0..<50) { index in
                                    Text(scrollAtTop ? "Item \(index)" : "Item \(index) - Scrolled")
                                }

                        }
                        .task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            presented = true
                        }
                        .onPreferenceChange(ScrollViewAtTopPreferenceKey.self) { value in
                            scrollAtTop = value
                        }
                    }
                } label: {
                    Label("Home", systemImage: "house")
                }

                Tab(value: 1) {

                } label: {
                    Label("Inventory", systemImage: "book")
                }
                Tab(value: 2) {

                } label: {
                    Label("Orders", systemImage: "shippingbox")
                }
                Tab(value: 3) {

                } label: {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right")
                }
                Tab(value: 4) {

                } label: {
                    Label("Customers", systemImage: "person.2")
                }
            }

        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: selectedTab == 0, content: {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button(action: {
                        // Action for the button
                    }) {
                        Label("Refer", systemImage: "qrcode.viewfinder")
                            .padding(8)


                    }
                    Divider()
                        .background(.primary)
                    Button(action: {
                        // Action for the button
                    }) {
                        Label("Add Customer", systemImage: "person.badge.plus")
                            .padding(8)

                    }
                    Divider()                        .background(.primary)
                    Button(action: {
                        // Action for the button
                    }) {
                        Label("Create Order", systemImage: "square.and.pencil")
                            .padding(8)

                    }
                }
                .padding()
                }
        })
        .tint(.black.opacity(0.8))
    }
}

#Preview {
    ContentView()
}
