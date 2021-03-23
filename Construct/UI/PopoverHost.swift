//
//  PopoverHost.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 29/08/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
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
    @State var present = false

    func makeUIViewController(context: UIViewControllerRepresentableContext<PopoverPresenter>) -> UIHostingController<EmptyView> {
        UIHostingController(rootView: EmptyView())
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

    func updateUIViewController(_ uiViewController: UIHostingController<EmptyView>, context: Context) {
        let popoverVC = uiViewController.presentedViewController as? UIHostingController<PopoverWrapper>
        if content != nil {
            popoverVC?.rootView = PopoverWrapper(popover: $content, present: $present)

            if popoverVC == nil {
                let newPopoverVC = UIHostingController(rootView: PopoverWrapper(popover: $content, present: $present))
                newPopoverVC.view.backgroundColor = .clear
                newPopoverVC.modalPresentationStyle = .overFullScreen
                context.coordinator.popoverVC = newPopoverVC
                uiViewController.present(newPopoverVC, animated: false)

                DispatchQueue.main.async {
                    withAnimation {
                        present = true
                    }
                }
            }
        }

        if content == nil && popoverVC != nil && popoverVC == context.coordinator.popoverVC {
            DispatchQueue.main.async {
                present = false
            }
            context.coordinator.popoverVC = nil
            uiViewController.dismiss(animated: false)
        }
    }

    struct PopoverWrapper: View {
        @Binding var popover: Popover?
        @Binding var present: Bool

        var body: some View {
            ZStack {
                if let popover = popover, present {
                    Color(UIColor.systemGray3).opacity(0.45).edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            $popover.wrappedValue = nil
                        }
                        .transition(.opacity)

                    popover
                        .padding(15)
                        .clipped()
                        .frame(maxWidth: 500)
                        .background(
                             Color(UIColor.systemBackground)
                                .cornerRadius(8)
                                .shadow(radius: 5)
                        )
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(
                            AnyTransition.offset(y: 50)
                                .combined(with: .scale(scale: 0.9))
                                .combined(with: AnyTransition.opacity.animation(.easeOut(duration: 0.1)))
                        )
                }
            }
            .animation(.spring())
        }
    }

}
