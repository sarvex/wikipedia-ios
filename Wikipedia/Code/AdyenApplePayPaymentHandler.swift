import Foundation
import Adyen
import AdyenNetworking
import PassKit
import AdyenComponents

// Note: A lot of this stuff is faked for now, DemoCheckoutAPI's should flow through Wikimedia server instead.
internal struct DemoAPIContext: AnyAPIContext {
    
    internal init(environment: AnyAPIEnvironment = DemoCheckoutAPIEnvironment.test) {
        self.environment = environment
    }
    
    internal let environment: AnyAPIEnvironment
    
    internal let headers: [String: String] = [
        "Content-Type": "application/json",
        "X-API-Key": AdyenConfigurationConstants.demoServerAPIKey
    ]
    
    internal let queryParameters: [URLQueryItem] = []
    
}

internal enum DemoCheckoutAPIEnvironment: String, AnyAPIEnvironment, CaseIterable {
    
    case beta, test, local
    
    internal var baseURL: URL {
        switch self {
        case .beta:
            return URL(string: "https://checkout-beta.adyen.com/checkout/v\(version)")!
        case .test:
            return URL(string: "https://checkout-test.adyen.com/v\(version)")!
        case .local:
            return URL(string: "http://localhost:8080/checkout/v\(version)")!
        }
    }
    
    static let apiVersion = 69

    internal var version: Int { Self.apiVersion }
    
}

struct AdyenConfigurationConstants {
    static var countryCode: String? {
        Locale.current.regionCode
    }
    
    static let clientKey = "{redacted}"
    static let demoServerAPIKey = "{redacted}"
    
    static let merchantAccount = "{redacted}"
    
    static let merchantIdentifier = "{redacted}"
    
    static var environment: AnyAPIEnvironment {
        return Environment.test
    }
    
    static let shopperReference = "{redacted}"
    
    static func applePaySummaryItems(amount: Decimal) -> [PKPaymentSummaryItem] {
        [
            PKPaymentSummaryItem(
                label: WMFLocalizedString("apple-pay-item-description", value: "Wikipedia Gift", comment: "Apple Pay item description. Appears in the Apple Pay payment sheet."),
                amount: amount as NSDecimalNumber,
                type: .final
            )
        ]
    }
    
    static let returnUrl = "wikipedia://explore"
   
}

protocol ApplePayPresenter: AnyObject {
    func present(viewController: UIViewController, completion: (() -> Void)?)
    func dismiss(completion: (() -> Void)?)
    func presentAlert(withTitle title: String)
    func presentAlert(with error: Error, retryHandler: (() -> Void)?)
}

@objc(WMFAdyenApplePayHandler)
class AdyenApplePayHandler: NSObject {
    
    lazy var demoApiClient = APIClient(apiContext: demoApiContext)
    
    lazy var demoApiContext = DemoAPIContext()
    
    lazy var apiContext = APIContext(environment: AdyenConfigurationConstants.environment, clientKey: AdyenConfigurationConstants.clientKey)
    
    @objc static var isSupported: Bool {
        return PKPaymentAuthorizationController.canMakePayments()
    }
    
    static var needsSetup: Bool {
        // TODO: fix supported networks
        return isSupported // && !PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks)
    }
    
    private var paymentMethods: PaymentMethods?
    private var payment: Payment?
    
    weak var presenter: ApplePayPresenter?
    
    func start(amount: Decimal) {
        
        guard let countryCode = Locale.current.regionCode, // TODO: needs to be "Country where Apple Pay is supported"
        let currencyCode = Locale.current.currencyCode else {
            // TODO: ERROR
            return
        }
        let minorAmount = AmountFormatter.minorUnitAmount(from: amount, currencyCode: currencyCode)
        
        let adyenAmount = Amount(value: minorAmount, currencyCode: currencyCode, localeIdentifier: Locale.current.identifier)
        self.payment = Payment(amount: adyenAmount, countryCode: countryCode)
        
        let request = AdyenPaymentMethodsRequest(amount: adyenAmount)
        demoApiClient.perform(request) { result in
            switch result {
            case let .success(response):
                self.paymentMethods = response.paymentMethods
                self.presentApplePayComponent(amount: amount)
            case let .failure(error):
                print(error)
            }
        }
    }
    
    // MARK: Adyen Components Presentation Code
    
    var currentComponent: ApplePayComponent?
    
    internal func presentApplePayComponent(amount: Decimal) {
        guard let paymentMethod = paymentMethods?.paymentMethod(ofType: ApplePayPaymentMethod.self),
        let payment = self.payment else { return }
        let config = ApplePayComponent.Configuration(summaryItems: AdyenConfigurationConstants.applePaySummaryItems(amount: amount),
                                                     merchantIdentifier: AdyenConfigurationConstants.merchantIdentifier)
        let component = try? ApplePayComponent(paymentMethod: paymentMethod,
                                               apiContext: apiContext,
                                               payment: payment,
                                               configuration: config)
        guard let presentableComponent = component else { return }
        // this seemingly needless property is actually super essential because the component deallocates without it, causing missing delegate callbacks 😩
        self.currentComponent = component
        present(presentableComponent)
    }
    
    private func present(_ component: PresentableComponent) {
        if let component = component as? PaymentAwareComponent {
            component.payment = payment
        }

        if let paymentComponent = component as? PaymentComponent {
            paymentComponent.delegate = self
        }

        presenter?.present(viewController: component.viewController, completion: nil)
    }
}

extension AdyenApplePayHandler: PaymentComponentDelegate {
    func didSubmit(_ data: PaymentComponentData, from component: PaymentComponent) {
        print("didSubmit-PaymentComponent")
        
        guard let amount = payment?.amount else {
            print("no amount")
            return
        }
        
        // Per https://docs.adyen.com/payment-methods/apple-pay/ios-component
        // Pass the data.paymentMethod to your server
        // From your server, make a /payments request, specifying: paymentMethod: The data.paymentMethod from your client app.
        let request = AdyenPaymentsRequest(data: data, amount: amount, reference: "{redacted}")
        demoApiClient.perform(request) { result in
            switch result {
            case let .success(response):
                print(response.resultCode)

                DispatchQueue.main.async {
                    component.finalizeIfNeeded(with: true)
                }

            case let .failure(error):
                print(error)
                DispatchQueue.main.async {
                    component.finalizeIfNeeded(with: false)
                }
            }
        }
    }
    
    func didFail(with error: Error, from component: PaymentComponent) {
        print("didFail-PaymentComponent")
    }
}

struct AdyenPaymentMethodsRequest: APIRequest {
    
    typealias ResponseType = AdyenPaymentMethodsResponse
    let path = "paymentMethods"
    var counter: UInt = 0
    var method: HTTPMethod = .post
    var headers: [String: String] = [:]
    var queryParameters: [URLQueryItem] = []
    
    let amount: Amount
    
    // MARK: - Encoding
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(AdyenConfigurationConstants.countryCode, forKey: .countryCode)
        try container.encode(AdyenConfigurationConstants.merchantAccount, forKey: .merchantAccount)
        try container.encode(amount, forKey: .amount)
    }
    
    enum CodingKeys: CodingKey {
        case countryCode
        case merchantAccount
        case amount
    }
    
}

struct AdyenPaymentMethodsResponse: Response {
    
    let paymentMethods: PaymentMethods
    
    init(from decoder: Decoder) throws {
        self.paymentMethods = try PaymentMethods(from: decoder)
    }
    
}

internal struct AdyenPaymentsRequest: APIRequest {
    
    internal typealias ResponseType = AdyenPaymentsResponse
    
    internal let path = "payments"
    
    internal let data: PaymentComponentData
    
    internal var counter: UInt = 0
    
    internal var method: HTTPMethod = .post
    
    internal var queryParameters: [URLQueryItem] = []
    
    internal var headers: [String: String] = [:]
    
    let amount: Amount
    let reference: String
    
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let amount = data.amount ?? amount
        
        try container.encode(data.paymentMethod.encodable, forKey: .details)
        try container.encode(data.storePaymentMethod, forKey: .storePaymentMethod)
        try container.encodeIfPresent(data.shopperName, forKey: .shopperName)
        try container.encodeIfPresent(data.emailAddress, forKey: .shopperEmail)
        try container.encodeIfPresent(data.billingAddress, forKey: .billingAddress)
        try container.encode(Locale.current.identifier, forKey: .shopperLocale)
        try container.encodeIfPresent(data.browserInfo, forKey: .browserInfo)
        try container.encode("iOS", forKey: .channel)
        try container.encode(amount, forKey: .amount)
        try container.encode(reference, forKey: .reference)
        try container.encode(AdyenConfigurationConstants.countryCode, forKey: .countryCode)
        try container.encode(AdyenConfigurationConstants.returnUrl, forKey: .returnUrl)
        try container.encode(AdyenConfigurationConstants.merchantAccount, forKey: .merchantAccount)
    }
    
    private enum CodingKeys: String, CodingKey {
        case details = "paymentMethod"
        case storePaymentMethod
        case amount
        case reference
        case channel
        case countryCode
        case returnUrl
        case shopperEmail
        case merchantAccount
        case browserInfo
        case shopperName
        case shopperLocale
        case billingAddress
    }
    
}

internal struct AdyenPaymentsResponse: Response {
    
    internal let resultCode: ResultCode
    
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.resultCode = try container.decode(ResultCode.self, forKey: .resultCode)
    }
    
    private enum CodingKeys: String, CodingKey {
        case resultCode
    }
    
}

internal extension AdyenPaymentsResponse {
    
    enum ResultCode: String, Decodable {
        case authorised = "Authorised"
        case refused = "Refused"
        case pending = "Pending"
        case cancelled = "Cancelled"
        case error = "Error"
        case received = "Received"
        case redirectShopper = "RedirectShopper"
        case identifyShopper = "IdentifyShopper"
        case challengeShopper = "ChallengeShopper"
        case presentToShopper = "PresentToShopper"
    }
    
}
