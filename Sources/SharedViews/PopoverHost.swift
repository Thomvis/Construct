//
//  PopoverHost.swift
//  Construct
//
//  Created by Thomas Visser on 29/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

public protocol Popover {
    // if popoverId changes, it is considered a new popover
    var popoverId: AnyHashable { get }
    func makeBody() -> AnyView
}

public extension View {
    func popover(_ content: Binding<Popover?>) -> some View {
        self.background(PopoverPresenter(
                            content: Binding(
                                get: { content.wrappedValue?.makeBody() },
                                set: { _ in content.wrappedValue = nil }
                            )).opacity(0))
    }

    func popover<Content>(_ content: Binding<Content?>) -> some View where Content: View {
        self.background(PopoverPresenter(content: content).opacity(0))
    }
}

// Inspired by https://www.objc.io/blog/2020/04/21/swiftui-alert-with-textfield/
struct PopoverPresenter<Popover>: UIViewControllerRepresentable where Popover: View {
    @Binding var content: Popover?

    func makeUIViewController(context: UIViewControllerRepresentableContext<PopoverPresenter>) -> UIViewController {
        UIViewController()
    }

    final class Coordinator {
        var popoverVC: UIHostingController<PopoverWrapper>?
        init(_ controller: UIHostingController<PopoverWrapper>? = nil) {
            self.popoverVC = controller
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let popoverVC = uiViewController.presentedViewController as? UIHostingController<PopoverWrapper>
        if content != nil {
            popoverVC?.rootView = PopoverWrapper(popover: $content)

            if popoverVC == nil {
                let newPopoverVC = UIHostingController(rootView: PopoverWrapper(popover: $content))
                newPopoverVC.view.backgroundColor = .clear
                newPopoverVC.modalPresentationStyle = .overFullScreen
                context.coordinator.popoverVC = newPopoverVC
                uiViewController.present(newPopoverVC, animated: false)
            }
        }

        if content == nil && popoverVC != nil && popoverVC == context.coordinator.popoverVC {
            context.coordinator.popoverVC = nil
            uiViewController.dismiss(animated: false)
        }
    }

    struct PopoverWrapper: View {
        @Binding var popover: Popover?

        var body: some View {
            ZStack {
                Color(UIColor.systemGray3).opacity(0.66).edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        $popover.wrappedValue = nil
                    }
                    .transition(.opacity)
                    .blendMode(.multiply)

                popover
                    .padding(15)
                    .clipped()
                    .frame(maxWidth: 500)
                    .background(
                         Color(UIColor.secondarySystemBackground)
                            .cornerRadius(8)
                            .shadow(radius: 5)
                    )
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

}
