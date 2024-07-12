//
//  New.swift
//  FeelingsApp
//
//  Created by Holygent on 6/27/24.
//

import Foundation
import SwiftUI

struct New: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(Defaults.self) var defaults
    let features: [(String, String, String)] = [("rectangle.stack.fill", "Lists", "Test people with your friends in real time."), ("person.line.dotted.person.fill", "New relationship", "Test people as “Other” so you don't need to think about your relationships."), ("sparkles", "UI Enhancements", "The whole app was resived to improve your experience."), ("ant.fill", "Bug fixes", "Many bugs were resolved and performace was greatly improved.")]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("What's New")
                        .font(.largeTitle.bold())
                        .padding(30)
                    Text("v0.2")
                        .font(.title3.bold())
                        .padding(.bottom,10)
                    (Text(Image(systemName: "exclamationmark.triangle.fill")).foregroundStyle(.yellow) + Text(" This version is a Beta."))
                        .font(.subheadline)
                        .padding(.bottom,50)
                    ForEach(features, id: \.0) { feature in
                        HStack {
                            Image(systemName: feature.0)
                                .font(.largeTitle)
                                .fontWeight(.medium)
                                .frame(width: 0.2*UIScreen.main.bounds.width, alignment: .center)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(feature.1)
                                    .font(.title2.bold())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom,5)
                                Text(feature.2)
                                    .font(.subheadline)
                            }
                        }
                        .multilineTextAlignment(.leading)
                        .padding(.bottom,25)
                    }
                    Text("and much more")
                        .foregroundStyle(Color.secondary)
                        .font(.subheadline)
                        .padding(.bottom,40)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal,40)
                .padding(.bottom,0.15*UIScreen.main.bounds.height+CGFloat(25))
            }
            .overlay(
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .padding(.vertical,8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.horizontal,100)
                .frame(height: 0.15*UIScreen.main.bounds.height)
                .background(.thickMaterial)
                .frame(maxHeight: .infinity, alignment: .bottom)
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .padding(1)
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }
        }
    }
}
