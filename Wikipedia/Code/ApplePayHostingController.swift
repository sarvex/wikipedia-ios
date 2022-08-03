import Foundation
import SwiftUI

class ApplePayHostingController<Content: View>: CustomUIHostingController<Content> {
    
    let paymentHandler: AdyenApplePayHandler
    
    init(rootView: Content, paymentHandler: AdyenApplePayHandler) {
        self.paymentHandler = paymentHandler
        
        super.init(rootView: rootView)
        
        paymentHandler.presenter = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ApplePayHostingController: ApplePayPresenter {
    func present(viewController: UIViewController, completion: (() -> Void)?) {
        print("present!")
        present(viewController, animated: true, completion: completion)
    }
    
    func dismiss(completion: (() -> Void)?) {
        print("dismiss!")
        dismiss(animated: true, completion: completion)
    }
    
    func presentAlert(withTitle title: String) {
        print("present alert: \(title)")
    }
    
    func presentAlert(with error: Error, retryHandler: (() -> Void)?) {
        print("present alert: \(error)")
    }
}
