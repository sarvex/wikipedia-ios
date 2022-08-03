import Foundation
import SwiftUI
import PassKit

@objc extension WMFSettingsViewController {
    @objc func showApplePay() {
        let paymentHandler = AdyenApplePayHandler()
        let contentView = ApplePayContentView(paymentHandler: paymentHandler)
        let hostingController = ApplePayHostingController(rootView: contentView, paymentHandler: paymentHandler)
        hostingController.title = WMFLocalizedString("apple-pay-title", value: "Donate", comment: "Title of the Apple Pay donation screen")
        navigationController?.pushViewController(hostingController, animated: true)
    }
}
