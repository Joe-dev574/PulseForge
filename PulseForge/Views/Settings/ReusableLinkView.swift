//
//  ReusableLinkView.swift
//  PulseForge
//
//  Created by Joseph DeWeese on 2/21/26.
//

import SwiftUI

struct ReusableLinkView: View {
    let iconName: String
    let linkText: String
    let destinationURL: URL
    let accessibilityIdentifier: String
    let accessibilityLabel: String
    let accessibilityHint: String
    let backgroundColor: Color
    let iconSize: CGFloat
    let rectangleSize: CGFloat
    let cornerRadius: CGFloat
    
    init(
        iconName: String,
        linkText: String,
        destinationURL: URL,
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        backgroundColor: Color = .blue,
        iconSize: CGFloat = 20,
        rectangleSize: CGFloat = 35,
        cornerRadius: CGFloat = 10
    ) {
        self.iconName = iconName
        self.linkText = linkText
        self.destinationURL = destinationURL
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.backgroundColor = backgroundColor
        self.iconSize = iconSize
        self.rectangleSize = rectangleSize
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        HStack {
            ZStack {
                Rectangle()
                    .fill(backgroundColor)
                    .frame(width: rectangleSize, height: rectangleSize)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                Image(systemName: iconName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(.white)
            }
            Link(linkText, destination: destinationURL)
                .foregroundStyle(.primary)
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(accessibilityHint)
        }
    }
}


