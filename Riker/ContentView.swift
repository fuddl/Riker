//
//  ContentView.swift
//  Riker
//
//  Created by Alex on 14.03.25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LibraryView()
            PlayerBar()
            ToastView()
        }
    }
}

#Preview {
    ContentView()
}
