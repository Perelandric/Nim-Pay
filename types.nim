import times

type
  ErrorCode* = enum
    invalid_request
    invalid_client
    invalid_grant
    unauthorized_client
    unsupported_grant_type
    invalid_scope

  PayPalException = object of Exception
    rawData*: string

  IdentityError = object of PayPalException
    error*: ErrorCode
    error_description*: string
    error_uri*: string

  HttpStatusError = object of PayPalException
    error_name*: string # `name` in JSON response
    message*: string
    information_link*: string

# Error Object (returned in the response)
  Error = object
    error_name*: string # `name` in JSON response; human readable unique name
    debug_id*: string # PayPal internal ID
    message*: string # Description of error
    information_link*: string # URL for more error info
    details*: ErrorDetails # Addtl details

# Error Details Object
  ErrorDetails = object
    field*: string # Name of field that caused the error
    issue*: string # Reason for the error

var ErrNoResults = fmt.Errorf("No results.")

var UnexpectedResponse = fmt.Errorf("Paypal server returned an unexpected response.")
var AmountMismatchError = fmt.Errorf("Sum of values doesn't match total amount.")


proc to_error*(self: IdentityError): error =
  return fmt.Errorf("PayPal error response:%q, Description:%q", self.error,
                                                        self.error_description)

proc to_error*(self: HttpStatusError): error =
  return fmt.Errorf("Http status error: %q, Message: %q, Info link: %q", hse.Name, hse.Message, hse.Information_link)

proc to_error*(self: Error): error =
  return fmt.Errorf("Payment error response: %q, Message: %q", pe.Name, pe.Message)



type
# Pagination
#  Assuming `start_time`, `start_index` and `start_id` are mutually exclusive
#  ...going to treat them that way anyhow until I understand better.

# I'm going to ignore `start_index` for now since I don't see its usefulness



# PaymentBatcher - Manages paginated requests for Payments

  PaymentBatcher* = object
    base_query*: string
    next_id*: string
    done*: bool
    connection*: Connection


# TODO: Should this hold the `execute` path so that it doesn't need to be constructed in `Execute()`?
  PaymentExecutor* = object
    id*: string
    state*: State
    payerID*: string
    payments*: Payments

  PaymentList = object
    payments*: seq[PaymentObject]
    count*: int
    next_id*: string


# array of SaleObject, AuthorizationObject, CaptureObject, or RefundObject
  RelatedResources = seq[RelatedResource]
  ResourceKind {.pure requiresInit.} = enum
    Sale
    Authorization
    Capture
    Refund

  RelatedResource = object
    case kind*: ResourceKind
    of ResourceKind.Sale:
      sale*: Sale
    of ResourceKind.Authorization:
      authorization*: Authorization
    of ResourceKind.Capture:
      capture*: Capture
    of ResourceKind.Refund:
      refund*: Refund




#---------------------
# Paypal Types
#---------------------

  NormalizationStatus* {.pure.} = enum # For Brazil payers
    UNKNOWN
    UNNORMALIZED_USER_PREFERRED
    NORMALIZED
    UNNORMALIZED

  AddressStatus* {.pure requiresInit.} = enum
    CONFIRMED
    UNCONFIRMED

  PaymentMode* {.pure requiresInit.} = enum
    INSTANT_TRANSFER
    MANUAL_BANK_TRANSFER
    DELAYED_TRANSFER
    ECHECK

  AuthorizationState* {.pure requiresInit.} = enum
    pending
    authorized
    captured
    partially_captured
    expired
    voided

  CreditCardState {.pure requiresInit.} = enum
    expired
    ok
  
  OrderState* {.pure requiresInit.} = enum
    PENDING
    COMPLETED
    REFUNDED
    PARTIALLY_REFUNDED

  PaymentState* {.pure requiresInit.} = enum
    created
    approved
    failed
    pending
    canceled
    expired
    in_progress

  RefundState* {.pure requiresInit.} = enum
    pending
    completed
    failed

  SaleState* {.pure requiresInit.} = enum
    pending
    completed
    refunded
    partially_refunded

  CaptureState* {.pure requiresInit.} = enum
    pending
    completed
    refunded
    partially_refunded

  PendingReason* {.pure requiresInit.} = enum
    PAYER_SHIPPING_UNCONFIRMED = "PAYER-SHIPPING-UNCONFIRMED"
    MULTI_CURRENCY = "MULTI-CURRENCY"
    RISK_REVIEW = "RISK-REVIEW"
    REGULATORY_REVIEW = "REGULATORY-REVIEW"
    VERIFICATION_REQUIRED = "VERIFICATION-REQUIRED"
    ORDER
    OTHER

  PaymentOpts* {.pure requiresInit.} = enum
    None
    INSTANT_FUNDING_SOURCE

  ReasonCode* {.pure requiresInit.} = enum
    CHARGEBACK
    GUARANTEE
    BUYER_COMPLAINT
    REFUND
    UNCONFIRMED_SHIPPING_ADDRESS
    ECHECK
    INTERNATIONAL_WITHDRAWAL
    RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION
    PAYMENT_REVIEW
    REGULATORY_REVIEW
    UNILATERAL
    VERIFICATION_REQUIRED

  AuthReason* {.pure.} = enum
    None
    AUTHORIZATION

  PayerStatus* {.pure requiresInit.} = enum
    UNVERIFIED
    VERIFIED

  ProtectionElig* {.pure.} = enum # Used if `payment_method` is `paypal`
    None
    INELIGIBLE # Merchant is not protected under the Seller Protection Policy.
    PARTIALLY_ELIGIBLE # Merchant is protected by PayPal’s Seller Protection
                       # Policy for Item Not Received or Unauthorized Payments.
                       # Refer to protection_eligibility_type for specifics.
    ELIGIBLE # Merchant is protected by PayPal’s Seller Protection Policy for
             # Unauthorized Payments and Item Not Received.

  ProtectionEligType* {.pure.} = enum
    None
    ITEM_NOT_RECEIVED_ELIGIBLE # Sellers protected against claims for items not received.
    UNAUTHORIZED_PAYMENT_ELIGIBLE # Sellers protected against claims for unauthorized payments.
                                  # One or both of the allowed values can be returned.

  FilterType* {.pure requiresInit.} = enum
    ACCEPT # An ACCEPT filter is triggered only for the TOTAL_PURCHASE_PRICE_MINIMUM
           # filter setting and is returned only in direct credit card payments
           # where payment is accepted.
    PENDING # Triggers a PENDING filter action where you need to explicitly
            # accept or deny the transaction.
    DENY # Triggers a DENY action where payment is denied automatically.
    REPORT # Triggers the Flag testing mode where payment is accepted.

  FilterId* {.pure requiresInit.} = enum
    MAXIMUM_TRANSACTION_AMOUNT # basic filter
    UNCONFIRMED_ADDRESS # basic filter
    COUNTRY_MONITOR # basic filter
    AVS_NO_MATCH # Address Verification Service No Match (advanced filter)
    AVS_PARTIAL_MATCH # Address Verification Service Partial Match (advanced filter)
    AVS_UNAVAILABLE_OR_UNSUPPORTED # Address Verification Service Unavailable or
                                   # Not Supported (advanced filter)
    CARD_SECURITY_CODE_MISMATCH # advanced filter
    BILLING_OR_SHIPPING_ADDRESS_MISMATCH # advanced filter
    RISKY_ZIP_CODE # high risk lists filter
    SUSPECTED_FREIGHT_FORWARDER_CHECK # high risk lists filter
    RISKY_EMAIL_ADDRESS_DOMAIN_CHECK # high risk lists filter
    RISKY_BANK_IDENTIFICATION_NUMBER_CHECK # high risk lists filter
    RISKY_IP_ADDRESS_RANGE # high risk lists filter
    LARGE_ORDER_NUMBER # transaction data filter
    TOTAL_PURCHASE_PRICE_MINIMUM # transaction data filter
    IP_ADDRESS_VELOCITY # transaction data filter
    PAYPAL_FRAUD_MODEL # transaction data filter

  TaxIdType* {.pure requiresInit.} = enum
    BR_CPF
    BR_CNPJ

  SortBy* {.pure requiresInit.} = enum
    Created = "create_time"
    Updated = "update_time"

  SortOrder* {.pure requiresInit.} = enum
    ASC
    DESC

  ConnectionType* {.pure requiresInit.} = enum
    sandbox
    live

  Intent* {.pure requiresInit.} = enum
    Sale = "sale"
    Authorize = "authorize"
    Order = "order"

  AddressType* {.pure requiresInit.} = enum
    Residential = "residential"
    Business = "business"
    Mailbox = "mailbox"

  PaymentMethod* {.pure requiresInit.} = enum
    CreditCard = "credit_card"
    PayPal = "paypal"

  CreditCardType* {.pure requiresInit.} = enum
    Visa = "visa"
    MasterCard = "mastercard"
    Discover = "discover"
    Amex = "amex"

# TODO: Remove this.
  State* {.pure requiresInit.} = enum
# sale/capture
    Completed = "completed"
# sale/capture
    Refunded = "refunded"
    PartiallyRefunded = "partially_refunded"

# 3 letter currency code as defined by ISO 4217.
  CurrencyType* {.pure requiresInit.} = enum
    AUD # Australian dollar
    BRL # Brazilian real**
    CAD # Canadian dollar
    CZK # Czech koruna
    DKK # Danish krone
    EUR # Euro
    HKD # Hong Kong dollar
    HUF # Hungarian forint
    ILS # Israeli new shekel
    JPY # Japanese yen*
    MYR # Malaysian ringgit**
    MXN # Mexican peso
    TWD # New Taiwan dollar*
    NZD # New Zealand dollar
    NOK # Norwegian krone
    PHP # Philippine peso
    PLN # Polish złoty
    GBP # Pound sterling
    SGD # Singapore dollar
    SEK # Swedish krona
    CHF # Swiss franc
    THB # Thai baht
    TRY # Turkish lira**
    USD # United States dollar



#--------------------------
# Common Payment Objects
#--------------------------


# Payer Object
  Payer* = object of RootObj
    payment_method*: PaymentMethod
    funding_instruments*: seq[FundingInstrument]
    payer_info*: PayerInfo

  PaymentPayer* = object of Payer
    status*: PayerStatus # Status of the payer’s PayPal account.
                         # Only supported when the payment_method is paypal.


# Payer Info Object (pre-filled by PayPal when the `payment_method` is `paypal`)
  PayerInfo* = object
    email*: string # Email address representing the payer. 127 characters max.
    salutation*: string # Salutation of the payer.
    first_name*: string # First name of the payer. Value assigned by PayPal.
    middle_name*: string # Middle name of the payer. Value assigned by PayPal.
    last_name*: string # Last name of the payer. Value assigned by PayPal.
    suffix*: string # Suffix of the payer.
    payer_id*: string # PayPal assigned Payer ID. Value assigned by PayPal.
    phone*: string # Phone number representing the payer. 20 characters max.
    country_code*: string # Two-letter registered country code of the payer to
                          # identify the buyer country.
    shipping_address*: ShippingAddress # Shipping address of payer PayPal account.
                                       # Value assigned by PayPal.
    billing_address*: Address
    tax_id_type*: TaxIdType # Payer’s tax ID type. Only supported when the
                            # Only supported when payment_method is paypal.
    tax_id*: string # Payer’s tax ID. Only supported when payment_method is paypal.



  BaseAddress* = object of RootObj
    line1*: string # 100 chars max; required
    line2*: string # 100 chars max
    city*: string # 50 chars max; required
    country_code*: string # 2 chars; required
    postal_code*: string # 20 chars max; required in some countries
    state*: string # 2 letter state code for US; 100 chars max for others
    phone*: string # E.123 format

# Address Object (for payments)
# This object is used for billing or shipping addresses.
  Address* = object of BaseAddress
    normalization_status*: NormalizationStatus # Only for Brazil payers
    status*: AddressStatus


# Shipping Address
  ShippingAddress* = object of Address
    recipient_name*: string # REQUIRED. Name of recip at address; 50 chars max.
    `type`*: AddressType # Address type.


# Funding Instrument Object
  FundingInstrument* = object
    credit_card*: CreditCard # CC details. REQUIRED if creating a funding instr.
    credit_card_token*: CreditCardToken # Token for stored CC details.
                                        # Use it in place of a Credit Card.
                                        # REQIURED if not passing `credit_card`.

  CCDetails* = object of RootObj
    `type`*: CreditCardType
    payer_id*: string # DEPRECATED in favor of `external_customer_id`.
                      # (Apparently not deprecated for Credit Card Token.)
                      # A unique identifier that you can assign and track when
                      # storing a credit card or using a stored credit card.
                      # This ID can help to avoid unintentional use or misuse of
                      # credit cards. This ID can be any value you would like to
                      # associate with the saved card, such as a UUID, username,
                      # or email address.
    expire_month*: string # 1-12; No leading 0; REQUIRED
    expire_year*: string # Four digit year; REQUIRED

# Credit Card Object
  CreditCard* = object of CCDetails
    id*: string # ID for stored card. REQUIRED when using a stored credit card.
    number*: string # Credit card number. Numeric characters only with no spaces
                    # or punctuation. The string must conform with modulo and
                    # length required by each credit card type. Redacted in responses.
                    # REQUIRED.
    cvv2*: string # 3-4 digit card validation code.
    first_name*: string # Cardholder first name
    last_name*: string # Cardholder last name
    billing_address*: Address

    # A unique identifier of the customer to whom this bank account belongs.
    # Generated and provided by the facilitator.
    external_customer_id*: string

    # A user-provided, optional field that functions as a unique identifier for
    # the merchant holding the card. This has no relation to PayPal merchant id.
    merchant_id*: string

    # A unique identifier of the bank account resource. Generated and provided
    # by the facilitator so it can be used to restrict the usage of the bank
    # account to the specific merchant.
    external_card_id*: string 

    create_time*: string # Resource creation time in ISO8601 date-time format
    update_time*: string #   (ex: 1994-11-05T13:15:30Z).

    state*: CreditCardState # Value assigned by PayPal.
    valid_until*: string # Funding instrument expiration date. Assigned by PayPal.
    links*: Links # HATEOAS links. Assigned by PayPal.


# Credit Card Token Object (Token corresponding to stored CC)
  CreditCardToken* = object of CCDetails
    credit_card_id*: string # ID of credit card previously stored using
                            # `/vault/credit-card`. REQUIRED.
    last4*: string # Value assigned by PayPal.

# Ffm Details Object (Fraud management filter)
  FmfDetails* = object
    filter_type*: FilterType
    filter_id*: FilterId # Name of the fraud management filter. For more information
                         # about filters, see Fraud Management Filters Summary.
    name*: string #  Name of the filter. This property is reserved for future use.
    description*: string # Description of the filter. This property is reserved
                         # for future use.

  Connection* = object
    `type`*: ConnectionType
    id*, secret*: string
    hosturl*: string #url.URL
    client*: string #http.Client
    tokeninfo*: TokenInfo

  # Not sure about this field. Appears in response, but not in documentation.
    app_id*: string

  # Derived fields
    expiration*: Time





# Payment Object
#   (Represents a payer’s funding instrument, such as a credit card or token
#    that represents a credit card.)
  PaymentObject* = object
    intent*: Intent # REQUIRED.
                    # `sale` for immediate payment,
                    # `authorize` to authorize a payment for capture later,
                    # `order` to create an order.

    # REQUIRED. Source of the funds for this payment represented by a PayPal
    # account or a direct credit card.
    payer*: PaymentPayer

    transactions*: seq[Transaction] # REQUIRED. Transactional details including
                                    # the amount and item details.
    redirect_urls*: RedirectURLs # REQUIRED for PayPal payments.
                              # Returned only when payment is in created state.
    id*: string # ID of the created payment. Value assigned by PayPal.
    create_time*: string # Value assigned by PayPal.
    state*: PaymentState # Value assigned by PayPal.
    update_time*: string # Value assigned by PayPal.
    experience_profile_id*: string # Identifier for the payment experience
    links*: Links # HATEOAS links


# Payment Execution Object
#   (This object includes information necessary to execute a PayPal account
#    payment with the `payer_id` obtained in the web `approval_url`.)
  PaymentExecution* = object
    payerId*: string # REQUIRED. ID of the Payer, passed in return_url by PayPal.
    transactions*: seq[Transaction] # REQUIRED. Transactional details including
                                    #   the amount and item details.

# Payment Options (payment options requested for the purchase unit)
  PaymentOptions = object
    # Optional payment method type.
    # If specified, the transaction will go through for only instant payment.
    # Only for use with the paypal payment_method, not relevant for credit_card.
    allowed_payment_method*: PaymentOpts


# Redirect URLs
#   A set of redirect URLs you provide to PayPal for PayPal account payments.
#   REQUIRED for PayPal account payments.
  RedirectURLs* = object
    return_url*: string # Payer is redirected here after approving the payment.
    cancel_url*: string # Payer is redirected here after canceling the payment.



# Transaction Object
  Transaction = object
    amount*: Amount # REQUIRED object
    description*: string # 127 chars max.
    item_list*: ItemList # Items and related shipping addr within a transaction
    related_resources*: RelatedResources # Financial transactions for payment
    invoice_number*: string # Invoice number used to track the payment.
                            # Only supported when the payment_method is paypal.
                            # 256 characters max.
    custom*: string # Free-form field for the use of clients.
                    # Only supported when the payment_method is set to paypal.
                    # 256 characters max.
    soft_descriptor*: string # Used when charging this funding source.
                             # Only supported when the payment_method is paypal.
                             # 22 characters max.
    payment_options*: PaymentOptions # Options requested for this purchase unit.




# Item List Object
  ItemList* = object of RootObj
    items*: seq[Item]
    shipping_address*: ShippingAddress

# Item Object
  Item* = object
    quantity*: string # Number of a particular item. 10 characters max. REQUIRED.
    name*: string # Item name. 127 characters max. REQUIRED.
    price*: string # Item cost. 10 characters max. REQUIRED.
    currency*: CurrencyType # 3-letter currency code. REQUIRED.
    sku*: string # Stock keeping unit corresponding (SKU) to item. 50 char max.
    description*: string # Description of the item. Only supported when the
                         # payment_method is set to paypal. 127 characters max.
    tax*: string # Tax of the item. Only supported when payment_method is paypal.

# Amount Object
  Amount = object
    currency*: CurrencyType # 3 char currency code; required
    total*: float64 # Total amount charged from the payer to the payee.
                    # In case of a refund, this is the refunded amount to the
                    # original payer from the payee.
                    # 10 characters max with support for 2 decimal places.
                    # REQUIRED.
    details*: Details

# Details Object (amount details)
  Details* = object
    shipping*: float64 # 10 chars max, with support for 2 decimal places
    subtotal*: float64 # 10 chars max, with support for 2 decimal places
                       # REQUIRED if line items are specified
    tax*: float64 # 10 chars max, with support for 2 decimal places
    handling_fee*: float64  # When `payment_method` is `paypal`
    insurance*: float64  # When `payment_method` is `paypal`
    shipping_discount*: float64  # When `payment_method` is `paypal`

  Links* = seq[Link]

  Link* = object
    href*: string
    rel*: string
    `method`*: string



  BaseTransmission = object of RootObj
    connection*: Connection
    id*: string # id of authorization; Value assigned by PayPal.
    amount*: Amount
    create_time*: string # Value assigned by PayPal.
    update_time*: string #   in http://tools.ietf.org/html/rfc3339#section-5.6
  
  BaseTransmissionWithElig = object of BaseTransmission
    clearing_time*: string # Expected clearing time for eCheck transactions.
                           # Only supported when the `payment_method` is set to
                           # `paypal`.
                           # Value assigned by PayPal.
    protection_eligibility*: ProtectionElig # If `payment_method` is `paypal`
    protection_eligibility_type*: ProtectionEligType # If eligible or partial.
                                                     # Both values can be returned.
    links*: Links # HATEOAS links. Value assigned by PayPal

  BaseTransmissionWithEligAndMode = object of BaseTransmissionWithElig
    payment_mode*: PaymentMode # Value assigned by PayPal.
                               # Only supported when the payment_method is paypal.
    fmf_details*: FmfDetails# Fraud Management Filter (FMF) details applied for
                            # the payment that could result in accept, deny, or
                            # pending action. Returned in a payment response only
                            # if the merchant has enabled FMF in the profile
                            # settings and one of the fraud filters was triggered
                            # based on those settings.

  BaseTransmissionWithEligModeAndParent = object of BaseTransmissionWithEligAndMode
    parent_payment*: string # id of parent pymt; Value assigned by PayPal.


# Order Object
  Order* = object of BaseTransmissionWithElig
    purchase_unit_reference_id: string # Identifier of the purchased unit
                                       # associated with this object.
    state*: OrderState
    pending_reason*: PendingReason # Reason the transaction is in pending state.
    reason_code*: ReasonCode # Reason code for the transaction state being Pending
                             # or Reversed. Only supported when the payment_method
                             # is set to paypal. Value assigned by PayPal.

# Refund Object
  Refund* = object of BaseTransmission
    state*: RefundState # Value assigned by PayPal.
    sale_id*: string # id of sale being refunded. Value assigned by PayPal.
    parent_payment*: string # id of parent pymt; Value assigned by PayPal.


# Sale Object
  Sale* = object of BaseTransmissionWithEligModeAndParent
    state*: SaleState # Value assigned by PayPal.
    description*: string # Description of sale.
    reason_code*: ReasonCode # Reason code for the transaction state being Pending
                             # or Reversed. Only supported when the payment_method
                             # is set to paypal. Value assigned by PayPal.
    transaction_fee*: Currency # Fee applicable for this payment
    receivable_amount*: Currency # Net amount the merchant receives for this
                                 # transaction in their receivable currency.
                                 # Returned only in cross-currency use cases
                                 # where a merchant bills a buyer in a
                                 # non-primary currency for that buyer.
    exchange_rate*: string # Exchange rate applied for this transaction.
                           # Returned only in cross-currency use cases where a
                           # merchant bills a buyer in a non-primary currency
                           # for that buyer.
    receipt_id*: string # 16-digit payment identification number returned for
                        # guest users to identify the payment.
 

# Authorization Object
  Authorization* = object of BaseTransmissionWithEligModeAndParent
    state*: AuthorizationState # Value assigned by PayPal
    reason_code*: AuthReason # AUTHORIZATION for a transaction state of pending
                             # Value assigned by PayPal.
    valid_until*: string # Authorization expiration; Value assigned by PayPal


# Capture Object
  Capture* = object of BaseTransmission
    state*: CaptureState # Value assigned by PayPal
    is_final_capture*: bool # If `true`, all remaining funds are released in the
                            # funding instrument. Default is `false`.
    links*: Links # HATEOAS links. Value assigned by PayPal
    transaction_fee*: Currency # Fee applicable for this payment
    parent_payment*: string # id of parent pymt; Value assigned by PayPal.





# Currency Object
#   Base object for all financial value related fields (balance, payment due, etc.)
  Currency* = object
    currency*: CurrencyType # REQUIRED.
    value*: string # REQUIRED. Amount up to N digit after the decimals separator
                   #  as defined in ISO 4217 for the appropriate currency code.


#---------------------------------
# Common Billling Plan Objects
#---------------------------------

  BillingPlanType* {.pure requiresInit.} = enum
    FIXED
    INFINITE

  BillingPlanState {.pure requiresInit.} = enum
    CREATED
    ACTIVE
    INACTIVE
    DELETED

  PaymentDefinitionTypes {.pure requiresInit.} = enum
    TRIAL
    REGULAR

  PaymentFrequency {.pure requiresInit.} = enum
    WEEK
    DAY
    YEAR
    MONTH

  ChargeModelsType {.pure requiresInit.} = enum
    SHIPPING
    TAX

  TermsType {.pure requiresInit.} = enum
    MONTHLY
    WEEKLY
    YEARLY

  AllowAutoBilling {.pure requiresInit.} = enum
    NO # default
    YES

  InitialFailAmountAction {.pure requiresInit.} = enum
    CONTINUE # default
    CANCEL

  RequestOperation {.pure requiresInit.} = enum
    add
    remove
    replace
    move
    copy
    test

# Plan Object
#   Billing plan resource that will be used to create a billing agreement.
  Plan* = object
    id*: string # Id of the billing plan. 128 characters max. Assigned in response.
    name*: string # REQUIRED. Name of the billing plan. 128 characters max.
    description*: string # REQUIRED. 128 characters max.
    `type`*: BillingPlanType # REQUIRED.
    state*: BillingPlanState # Assigned in response.

    # Time when the billing plan was created/updated.
    # Format YYYY-MM-DDTimeTimezone, as defined in ISO8601. Assigned in response.
    create_time*: string
    update_time*: string

    payment_definitions*: seq[PaymentDefinition] # Payment defs for this billing plan.
    terms*: seq[Terms] # Terms for this billing plan. Assigned in response.
    merchant_preferences*: MerchantPreferences # Prefs for this billing plan.
    links*: Links # HATEOAS links for this call. Assigned in response.


# Payment Definition Object
#   Resource representing payment definition scheduling information.
  PaymentDefinition* = object
    id*: string # 128 characters max. Assigned in response.
    name*: string # REQUIRED. Name of the payment definition. 128 characters max.
    `type`*: PaymentDefinitionTypes # REQUIRED.

    # REQUIRED. How frequently the customer should be charged.
    # It can’t be more than 12 months.
    frequency_interval*: string

    frequency*: string # REQUIRED. Frequency of the payment definition offered.

    # REQUIRED. Number of cycles in this payment definition. For INFINITE type
    # plans, cycles should be set to 0 for a REGULAR type payment_definition.
    cycles*: string 

    # REQUIRED. Amount that will be charged at the end of each cycle for this def.
    amount*: Currency

    charge_models*: seq[ChargeModels] # charge_models for this payment definition.


# Charge Models Object
#   A resource representing a charge model for a payment definition.
  ChargeModels* = object
    id*: string # 128 characters max. Assigned in response.
    `type`*: ChargeModelsType # REQUIRED.
    amount*: Currency  # REQUIRED. Specific amount for this charge model.


# Terms Object
#   Resource representing terms used by the plan.
  Terms* = object
    id*: string # 128 characters max. Assigned in response.
    `type`*: TermsType # REQUIRED.
    max_billing_amount*: Currency # REQUIRED. Max Amount associated with this term.
    occurrences*: string # REQUIRED. How many times money can be pulled during this term.
    amount_range*: Currency # REQUIRED. Amount_range associated with this term.
    buyer_editable*: string # REQUIRED. Buyer’s ability to edit the amount in this term.


# Merchant Preferences Object
#   Resource representing merchant preferences like max failed attempts, set up
#   fee and others for a plan.
  MerchantPreferences* = object
    id*: string # 128 characters max. Assigned in response.
    setup_fee*: Currency # Setup fee amount. Default is 0.

    # REQUIRED. 1000 characters max.
    cancel_url*: string # Redirect URL on cancellation of agreement request.
    return_url*: string # Redirect URL on creation of agreement request.

    # Notify URL on agreement creation. 1000 characters max. Read-only and
    # reserved for future use. Assigned in response.
    notify_url*: string

    # Total number of failed attempts allowed.
    # Default is 0, representing an infinite number of failed attempts.
    max_fail_attempts*: string

    # Allow auto billing for the outstanding amount of the agreement in the next cycle.
    auto_bill_amount*: AllowAutoBilling # Default is NO

    # Action to take if a failure occurs during initial payment.
    initial_fail_amount_action*: InitialFailAmountAction # Default is CONTINUE.

    # Payment types that are accepted for this plan. Assigned in response.
    accepted_payment_type*: string

    char_set*: string # char_set for this plan. Assigned in response.


# Patch Request Object
#   Request object used for a JSON Patch.
  PatchRequest* = object
    op*: RequestOperation # REQUIRED. The operation to perform.

    # String containing a JSON-Pointer value that references a location within
    # the target document where the operation is performed. Assigned in response.
    path*: string

    # New value to apply based on the operation. op=remove does not require
    # value. Assigned in response.
    value*: string # TODO: The type in PP docs is `object`. What does that mean?

    # A string containing a JSON Pointer value that references the location in
    # the target document from which to move the value. Required for use where
    # op=move. Assigned in response.
    `from`*: string

# Plan List Object
# Resource representing a list of billing plans with basic information and get link.
  PlanList* = object
    plans*: seq[Plan] # Array of billing plans.
    total_items*: string # Total number of items. Assigned in response.
    total_pages*: string # Total number of pages. Assigned in response.
    links*: Links # HATEOAS links related to this call.


#-----------------------------------
# Common Billling Agreement Objects
#-----------------------------------

  AgreementState* {.pure requiresInit.} = enum
    Active
    Pending
    Expired
    Suspend
    Reactivate
    Cancel

  AgreementTransactionState* {.pure requiresInit.} = enum
    Created
    Suspended
    Reactivated
    Canceled
    Completed
  
# Agreement Object
  Agreement* = object
    id*: string # Identifier of the agreement. Assigned in response.
    state*: AgreementState # State of the agreement. Assigned in response.
    name*: string # Name of the agreement. Required.
    description*: string # Description of the agreement. Required.
    start_date*: string # REQUIRED. Start date of the agreement.
                        # Date format yyyy-MM-dd z, as defined in ISO8601.

    agreement_details*: AgreementDetails # Details of the agreement.

    # REQUIRED. Details of the buyer enrolling in this agreement. This
    # information is gathered from execution of approval URL.
    payer*: Payer

    shipping_address*: Address # Shipping address object of the agreement,
                               #  which should be provided if it is different
                               #  from the default address.

    # Default merchant preferences from the billing plan are used, unless
    # override preferences are provided here.
    override_merchant_preferences*: MerchantPreferences

    # Array of override_charge_model for this agreement if needed to change
    # the default models from the billing plan.
    override_charge_models*: seq[OverrideChargeModel]

    plan*: Plan # REQUIRED. Plan details for this agreement.

    # Date and time that this resource was created/updated.
    # Date format yyyy-MM-dd z, as defined in ISO8601.
    # Assigned in response.
    create_time*: string
    update_time*: string

    links*: Links # HATEOAS links related to this call. Assigned in response.


# Agreement Details Object
  AgreementDetails* = object
    outstanding_balance*: Currency # The outstanding balance for this agreement.
    cycles_remaining*: string # Number of cycles remaining for this agreement.
    cycles_completed*: string # Number of cycles completed for this agreement.

    # The next_billing/last_payment/final_payment date for this agreement,
    # represented as 2014-02-19T10:00:00Z format.
    next_billing_date*: string
    last_payment_date*: string
    final_payment_date*: string

    last_payment_amount*: Currency # Last payment amount for this agreement.
    failed_payment_count*: string # Total failed payments for this agreement.


# Override Charge Model Object
# A resource representing an override_charge_model to be used during creation
# of the agreement.
  OverrideChargeModel* = object
    charge_id*: string # REQUIRED. ID of charge model.
    amount*: Currency # REQUIRED. Updated Amount to associate with charge model.


# Agreement State Descriptor Object
# Description of the current state of the agreement.
  AgreementStateDescriptor* = object
    note*: string # Reason for changing the state of the agreement.

    # The amount and currency of the agreement. It is required to bill
    # outstanding amounts, but is not required when suspending, cancelling or
    # reactivating an agreement.
    amount*: Currency


# Agreement Transactions Object
# A resource representing agreement_transactions that is returned during a
# transaction search.
  AgreementTransactions* = object
    agreement_transaction_list*: seq[AgreementTransaction]


# Agreement Transaction Object
# A resource representing an agreement_transaction that is returned during a
# transaction search.
  AgreementTransaction* = object
    transaction_id*: string # Assigned in response.

    # State of the subscription at this time. Assigned in response.
    status*: AgreementTransactionState

    # Type of transaction, usually Recurring Payment. Assigned in response.
    transaction_type*: string
    amount*: Currency # REQUIRED. Amount for this transaction.
    fee_amount*: Currency # REQUIRED. Fee amount for this transaction.
    net_amount*: Currency # REQUIRED. Net amount for this transaction.
    payer_email*: string # Email id of payer. Assigned in response.
    payer_name*: string # Business name of payer. Assigned in response.
    time_stamp*: string # Time at which transaction happened. Assigned in response.
    time_zone*: string # Time zone of time_updated field. Assigned in response.



#------------------------------
# Common Objects for Payouts
#------------------------------

  RecipientType* {.pure requiresInit.} = enum
    EMAIL
    PHONE
    PAYPAL_ID

  BatchStatus* {.pure requiresInit.} = enum
    DENIED
    PENDING
    PROCESSING
    SUCCESS

  TransactionStatus* {.pure requiresInit.} = enum
    SUCCESS
    DENIED
    PENDING
    PROCESSING
    FAILED
    UNCLAIMED
    RETURNED
    ONHOLD
    BLOCKED
    CANCELLED

# Payouts Batch Request Object
#   This object represents a set of payouts that includes status data for the
#   payouts. This object enables you to create a payout using a POST request.
  PayoutsBatchRequest* = object
    # The original batch header as provided by the payment sender.
    sender_batch_header*: SenderBatchHeader # REQUIRED.

    # An array of payout items (that is, a set of individual payouts).
    items*: seq[PayoutItem] # REQUIRED.


# Sender Batch Header Object
#   This object represents sender-provided data about a batch header. The data is
#   provided in a POST request. All batch submissions must have a batch header.
  SenderBatchHeader* = object
    # Sender-created ID for tracking the batch payout in an accounting system.
    sender_batch_id*: string # 30 characters max.

    # The subject line text for the email that PayPal sends when a payout item
    # is completed. (The subject line is the same for all recipients.)
    email_subject*: string # Maximum of 255 single-byte alphanumeric characters.

    # The type of ID for a payment receiver. If this field is provided, the payout
    # items without a recipient_type will use the provided value. If this field is
    # not provided, each payout item must include a value for the recipient_type.
    recipient_type*: RecipientType


# Payout Item Object
#   Sender-created description of a payout to a single recipient.
  PayoutItem* = object
    # The type of identification for the payment receiver. If this field is
    # provided, the payout items without a recipient_type will use the provided
    # value. If this field is not provided, each payout item must include a
    # value for the recipient_type.
    recipient_type*: RecipientType

    amount*: Currency # REQUIRED. The amount of money to pay a receiver.

    # Note for notifications. The note is provided by the payment sender.
    # This note can be any string.
    note*: string # 4000 characters max. Assigned in response.
 
    # The receiver of the payment. In a call response, the format of this value
    # corresponds to the recipient_type specified in the request.
    receiver*: string # REQUIRED. 127 characters max.

    # A sender-specific ID number, used in an accounting system for tracking purposes.
    sender_item_id*: string # 30 characters max. Assigned in response.


# Payouts Batch Response Object
#   Response to a POST request that creates a payout.
  PayoutsBatchResponse* = object
    batch_header*: BatchHeader # Batch header resource.
    links*: Links # HATEOAS links.


# Batch Header Object
#   Batch header resource.
  BatchHeader* = object
    # An ID for a batch payout. Generated by PayPal.
    payout_batch_id*: string # 30 characters max.

    # The generated batch status. If the batch passes the elementary checks, the
    # status will be PENDING.
    batch_status*: BatchStatus

    # The original batch header as provided by the payment sender.
    sender_batch_header*: SenderBatchHeader # REQUIRED.


# Batch Status Object
#   The batch status as generated by PayPal.
  BatchStatusObject* = object
    # A batch header that includes the generated batch status.
    batch_header*: BatchHeader # REQUIRED.

    items*: seq[PayoutItemDetails] # REQUIRED. The items in a batch payout.


# Payout Item Details Object
#   This object contains status and other data for an individual payout of a batch.
  PayoutItemDetails* = object

    # An ID for an individual payout. Provided by PayPal, such as in the case of
    # getting the status of a batch request.
    payout_item_id*: string # REQUIRED. 30 characters max.

    transaction_id*: string # Generated ID for the transaction. 30 characters max.

    transaction_status*:TransactionStatus # Status of a transaction.

    payout_item_fee*: Currency # Amount of money in U.S. dollars for fees.

    # An ID for the batch payout. Generated by PayPal.
    payout_batch_id*: string # REQUIRED. 30 characters max.

    # Sender-created ID for tracking the batch in an accounting system.
    sender_batch_id*: string # 30 characters max.

    # The data for a payout item that the sender initially provided.
    payout_item*: PayoutItem # REQUIRED.

    time_processed*: string # REQUIRED. Time of the last processing for this item.

    errors*: Error # Details of an Error
    links*: Links # HATEOAS links




#--------------------------
# Common Identity Objects
#--------------------------

  AccountType* {.pure requiresInit.} = enum
    personal
    business


# Identity Address Object
  IdentityAddress* = object
    street_address*: string
    locality*: string
    region*: string
    postal_code*: string
    country*: string

# Token Info Object
  TokenInfo* = object
    # https://developer.paypal.com/webapps/developer/docs/integration/direct/identity/attributes/
    scope*: string # REQUIRED if different from the scope requested by the client.

    access_token*: string # The access token issued by the authorization server.

    # The refresh token, which can be used to obtain new access tokens using the
    # same authorization grant as described in OAuth2.0 RFC6749 - Section 6.
    refresh_token*: string

    # The type of the token issued as described in
    # OAuth2.0 RFC6749 - Section 7.1. Value is case insensitive.
    token_type*: string

    # The lifetime of the access token in seconds. After the access token
    # expires, use the refresh_token to refresh the access token.
    # https://developer.paypal.com/webapps/developer/docs/api/#grant-token-from-refresh-token
    expires_in*: uint


# XXX: These were in the original code for some reason.
#    sub*: string
#    middle_name*: string
#    picture*: string
  UserInfo* = object
    user_id*: string # Identifier for the End-User at the Issuer.

    # End-User’s full name in displayable form including all name parts,
    # possibly including titles and suffixes, ordered according to the
    # End-User’s locale and preferences.
    name*: string

    given_name*: string # Given name(s) or first name(s) of the End-User.
    family_name*: string # Surname(s) or last name(s) of the End-User.
    email*: string # End-User’s preferred e-mail address.
    verified*: bool # True if the End-User’s e-mail address has been verified.
    gender*: string # End-User’s gender.

    # End-User’s birthday, represented as an YYYY-MM-DD format. They year MAY
    # be 0000, indicating it is omited. To represent only the year, YYYY format
    # would be used.
    birthdate*: string

    zoneinfo*: string # Time zone database representing the End-User’s time zone.
    locale*: string # End-User’s locale.
    phone_number*: string # End-User’s preferred telephone number.
    address*: IdentityAddress # End-User’s preferred address.
    verified_accoun*: bool # Verified account status.
    account_type*: AccountType
    age_rang*: string # Account holder age range.
    payer_id*: string # Account payer identifier.




#--------------------------
# Common Invoicing Objects
#--------------------------

  InvoiceStatus* {.pure requiresInit.} = enum
    DRAFT
    SENT
    PAID
    MARKED_AS_PAID
    CANCELLED
    REFUNDED
    PARTIALLY_REFUNDED
    MARKED_AS_REFUNDED

  Language* {.pure.} = enum
    da_DK, de_DE, en_AU, en_GB, en_US, es_ES, es_XC, fr_CA, fr_FR, fr_XC, he_IL
    id_ID, it_IT, ja_JP, nl_NL, no_NO, pl_PL, pt_BR, pt_PT, ru_RU, sv_SE, th_TH
    tr_TR, zh_CN, zh_HK, zh_TW, zh_XC

  TermType* {.pure requiresInit.} = enum
    DUE_ON_RECEIPT
    NET_10
    NET_15
    NET_30
    NET_45

  DetailType* {.pure requiresInit.} = enum
    PAYPAL
    EXTERNAL

  TransactionType* {.pure requiresInit.} = enum
    SALE
    AUTHORIZATION
    CAPTURE
  PaymentDetailMethod* {.pure requiresInit.} = enum
    BANK_TRANSFER
    CASH
    CHECK
    CREDIT_CARD
    DEBIT_CARD
    PAYPAL
    WIRE_TRANSFER
    OTHER

# Invoice Object
#   Detailed invoice information.
  Invoice* = object
    id*: string # Unique invoice resource identifier. Assigned in response.

    # Unique number that appears on the invoice. If left blank will be
    # auto-incremented from the last number.
    number*: string # 25 characters max.

    uri*: string #  URI of the invoice resource. Assigned in response.
    status*: InvoiceStatus #  Status of the invoice. Assigned in response.

    # Information about the merchant who is sending the invoice.
    merchant_info*: MerchantInfo # Required.

    # Email address of invoice recipient (required) and optional billing
    # information. (Note: We currently only allow one recipient).
    billing_info*: seq[BillingInfo]

    # Shipping information for entities to whom items are being shipped.
    shipping_info*: seq[ShippingInfo]

    # List of items included in the invoice.
    items*: seq[InvoiceItem] # 100 items max per invoice.

    # Date on which the invoice was enabled.
    invoice_date*: string # Date format yyyy-MM-dd z, as defined in ISO8601.

    # Optional field to pass payment deadline for the invoice. Either term_type
    # or due_date can be passed, but not both.
    payment_term*: PaymentTerm

    discount*: Cost # Invoice level discount in percent or amount.
    shipping_cost*: ShippingCost # Shipping cost in percent or amount.

    # Custom amount applied on an invoice. If a label is included then the
    # amount cannot be empty.
    custom*: CustomAmount

    # Indicates whether tax is calculated before or after a discount.
    # If false (the default), the tax is calculated before a discount.
    # If true, the tax is calculated after a discount.
    tax_calculated_after_discount*: bool

    # A flag indicating whether the unit price includes tax. Default is false
    tax_inclusive*: bool

    terms*: string # General terms of the invoice. 4000 characters max.
    note*: string # Note to the payer. 4000 characters max.

    # Bookkeeping memo that is private to the merchant.
    merchant_memo*: string # 150 characters max.

    # Full URL of an external image to use as the logo.
    logo_url*: string # 4000 characters max.

    total_amount*: Currency # The total amount of the invoice. Assigned in response.
    payments*: seq[PaymentDetail] # Payment details for the invoice. Assigned in response.
    refunds*: seq[RefundDetail] # Refund details for the invoice. Assigned in response.
    metadata*: Metadata # Audit information for the invoice. Assigned in response.


# Invoice Item Object
#   Information about a single line item.
  InvoiceItem* = object
    name*: string # REQUIRED. Name of the item. 60 characters max.
    description*: string # Description of the item. 1000 characters max.
    quantity*: int # REQUIRED. Quantity of the item. Range of 0 to 9999.999.

    # Unit price of the item.
    unit_price*: Currency # REQUIRED. Range of -999999.99 to 999999.99.

    tax*: Tax # Tax associated with the item.

    # Date on which the item or service was provided.
    date*: string # Date format yyyy-MM-dd z, as defined in ISO8601.

    discount*: Cost # Item discount in percent or amount.


# Shipping Info Object
#   Shipping information for the invoice recipient.
  ShippingInfo* = object of RootObj
    first_name*: string # First name of the invoice recipient. 30 characters max.
    last_name*: string # Last name of the invoice recipient. 30 characters max.
    address*: Address # Address of the invoice recipient.

    # Company business name of the invoice recipient.
    business_name*: string # 100 characters max.


# Merchant Info Object
#   Business information of the merchant that will appear on the invoice.
  MerchantInfo* = object of ShippingInfo
    email*: string # REQUIRED. Email address of the merchant. 260 characters max.
    phone*: Phone # Phone number of the merchant.
    fax*: Phone # Fax number of the merchant.
    website*: string # Website of the merchant. 2048 characters max.
    tax_id*: string # Tax ID of the merchant. 100 characters max.

    # Option to display additional information such as business hours.
    additional_info*: string # 40 characters max.


# Billing Info Object
#   Billing information for the invoice recipient.
  BillingInfo* = object of ShippingInfo
    email*: string # REQUIRED. Email address of the merchant. 260 characters max.

    # Language of the email sent to the payer.
    # Will only be used if payer doesn’t have a PayPal account.
    language*: Language

    # Option to display additional information such as business hours.
    additional_info*: string # 40 characters max.


# Payment Term Object
#   Payment term of the invoice. If term_type is present, due_date must not be
#   present and vice versa.
  PaymentTerm* = object
    term_type*: TermType # Terms by which the invoice payment is due.

    # Date on which invoice payment is due. It must be always a future date.
    due_date*: string # Date format yyyy-MM-dd z, as defined in ISO8601.


# Cost Object
#   Cost as a percent. For example, 10% should be entered as 10. Alternatively,
#   cost as an amount. For example, an amount of 5 should be entered as 5.
  Cost* = object
    percent*: int # Cost in percent. Range of 0 to 100.
    amount*: Currency # Cost in amount. Range of 0 to 999999.99.


# Shipping Cost Object
#   Shipping cost in percent or amount.
  ShippingCost* = object
    amount*: Currency # Shipping cost in amount. Range of 0 to 999999.99.
    tax*: Tax # Tax percentage on shipping amount.


# Tax Object
#   Tax information.
  Tax* = object
    id*: string # Identifier of the resource. Assigned in response.
    name*: string # REQUIRED. Name of the tax. 10 characters max.
    percent*: int # REQUIRED. Rate of the specified tax. Range of 0.001 to 99.999.

    # Tax in the form of money. Cannot be specified in a request.
    amount*: Currency # Assigned in response.


# Custom Amount Object
#   Custom amount applied on an invoice. If a label is included then the amount
#   cannot be empty.
  CustomAmount* = object
    label*: string # Custom amount label. 25 characters max.
    amount*: Currency # Custom amount value. Range of 0 to 999999.99.


# Refund Detail Object
#   Invoicing refund information.
  RefundDetail* = object of RootObj
    # PayPal payment detail indicating whether payment was made in an invoicing
    # flow via PayPal or externally. In the case of the mark-as-paid API, payment
    # type is EXTERNAL and this is what is now supported.
    # The PAYPAL value is provided for backward compatibility.
    `type`*: DetailType # Assigned in response.

    # Date when the invoice was marked as refunded.
    # If no date is specified, the current date and time is used as the default.
    # In addition, the date must be after the invoice payment date.
    date*: string # Date format yyyy-MM-dd z, as defined in ISO8601.

    note*: string # Optional note associated with the refund.


# Payment Detail Object
#   Invoicing payment information.
#
#   ! NOTE: The `date` field restrictions listed above do not apply here.
  PaymentDetail* = object of RefundDetail
    # PayPal payment transaction id. Assigned in response.
    transaction_id*: string # REQUIRED in case the type value is PAYPAL.

    transaction_type*: TransactionType # Assigned in response.

    # Payment mode or method.
    # This field is mandatory if the value of the type field is OTHER.
    `method`*: PaymentDetailMethod # REQUIRED.


# Metadata Object
#   Audit information of the resource.
  Metadata* = object
    # Email address of the account that created/last updated/last sent the resource.
    created_by*: string # Assigned in response.
    last_updated_by*: string # Assigned in response.
    last_sent_by*: string # Assigned in response.

    cancelled_by*: string # Actor who cancelled the resource. Assigned in response.

    created_date*: string # Date resource was created. Assigned in response.
    cancelled_date*: string # Date resource was cancelled. Assigned in response.
    last_updated_date*: string # Date resource was last edited. Assigned in response.
    first_sent_date*: string # Date resource was first sent. Assigned in response.
    last_sent_date*: string # Date resource was last sent. Assigned in response.



# Phone Object
#   Representation of a phone number.
  Phone* = object
    # Country code (in E.164 format).
    country_code*: string # REQUIRED. Assume length is n.

    # In-country phone number (in E.164 format).
    national_number*: string # REQUIRED. Maximum (15 - n) digits.


# Notification Object
#   Email/SMS notification.
  Notification* = object
    subject*: string # Subject of the notification.
    note*: string # Note to the payer.

    # A flag indicating whether a copy of the email has to be sent to the merchant.
    send_to_merchant*: bool


# Search Object
#   Invoice search parameters.
  Search* = object
    email*: string # Initial letters of the email address.
    recipient_first_name*: string # Initial letters of the recipient’s first name.
    recipient_last_name*: string # Initial letters of the recipient’s last name.
    recipient_business_name*: string # Initial letters of the recipient’s business name.
    number*: string # The invoice number that appears on the invoice.
    status*: InvoiceStatus # Status of the invoice.
    lower_total_amount*: Currency # Lower limit of total amount.
    upper_total_amount*: Currency # Upper limit of total amount.

    # Date format yyyy-MM-dd z, as defined in ISO8601.
    start_invoice_date*: string
    end_invoice_date*: string
    start_due_date*: string
    end_due_date*: string
    start_payment_date*: string
    end_payment_date*: string
    start_creation_date*: string
    end_creation_date*: string

    page*: int # Offset of the search results.
    page_size*: int # Page size of the search results.
    total_count_required*: bool # A flag indicating whether total count is required in the response.


# Cancel Notification Object
#   Email/SMS notification.
  CancelNotification* = object
    subject*: string # Subject of the notification.
    note*: string # Note to the payer.

    # A flag indicating whether a copy of the email has to be sent to the
    # merchant/payer.
    send_to_merchant*: bool
    send_to_payer*: bool



#----------------------------------
# Common Payment Experience Objects
#----------------------------------

  LocaleCode* {.pure requiresInit.} = enum
    AU, AT, BE, BR, CA, CH, CN, DE, ES, GB, FR, IT, NL, PL, PT, RU, US,
    da_DK, he_IL, id_ID, ja_JP, no_NO, pt_BR, ru_RU, sv_SE, th_TH, tr_TR,
    zh_CN, zh_HK, zh_TW


# Web Profile Object
#   Payment Web experience profile resource
  WebProfile* = object
    id*: string # Unique ID of the web experience profile. Assigned in response.

    # Name of the web experience profile. Unique only among the profiles for a
    # given merchant.
    name*: string # REQUIRED.

    flow_config*: FlowConfig # Parameters for flow configuration.
    input_fields*: InputFields # Parameters for input fields customization.
    presentation*: Presentation # Parameters for style and presentation.


# Flow Config Object
#   Parameters for flow configuration.
  FlowConfig* = object
    landing_page_type*: string #  Type of PayPal page to be displayed when a user lands on the PayPal site for checkout. Allowed values: Billing or Login. When set to Billing, the Non-PayPal account landing page is used. When set to Login, the PayPal account login landing page is used.
    bank_txn_pending_url*: string #  The URL on the merchant site for transferring to after a bank transfer payment. Use this field only if you are using giropay or bank transfer payment methods in Germany.


# Input Fields Object
#   Parameters for input fields customization.
  InputFields* = object
    # Enables the buyer to enter a note to the merchant on the PayPal page
    # during checkout.
    allow_note*: bool

    # Determines whether or not PayPal displays shipping address fields on the
    # experience pages. Allowed values: 0, 1, or 2.
    # When set to 0, PayPal displays the shipping address on the PayPal pages.
    # When set to 1, PayPal does not display shipping address fields whatsoever.
    # When set to 2, if you do not pass the shipping address, PayPal obtains it
    # from the buyer’s account profile.
    # For digital goods, this field is REQUIRED, and you must set it to 1.
    no_shipping*: range[0..2]

    # Determines if the PayPal pages should display the shipping address supplied
    # in this call, rather than the shipping address on file with PayPal for this
    # buyer.
    # Displaying the address on file does not allow the buyer to edit the address.
    # Allowed values: 0 or 1.
    # When set to 0, the PayPal pages should display the address on file.
    # When set to 1, the PayPal pages should display the addresses supplied in
    # this call instead of the address from the buyer’s PayPal account.
    address_override*: range[0..1]


# Presentation Object
#   Parameters for style and presentation.
  Presentation* = object
    # A label that overrides the business name in the PayPal account on the
    # PayPal pages.
    brand_name*: string # max 127 single-byte alphanumeric characters.

    # A URL to logo image. Allowed vaues: .gif, .jpg, or .png.
    # Limit the image to 190 pixels wide by 60 pixels high.
    # PayPal crops images that are larger.
    # PayPal places your logo image at the top of the cart review area.
    # PayPal recommends that you store the image on a secure (https) server.
    # Otherwise, web browsers display a message that checkout pages contain
    # non-secure items.
    logo_image*: string # max 127 single-byte alphanumeric characters.

    locale_code*: LocaleCode # Locale of pages displayed by PayPal payment experience.


# Create Profile Response Object
#   Response schema for create profile api
  CreateProfileResponse* = object
    id*: string # ID of the payment web experience profile.


# Patch Request Object
#   Request object used for a JSON Patch.
  PathRequest* = object
    op*: RequestOperation # REQUIRED. The operation to perform.

    # string containing a JSON-Pointer value that references a location within
    # the target document (the target location) where the operation is performed.
    path*: string # REQUIRED.

    value*: string # New value to apply based on the operation.

    # A string containing a JSON Pointer value that references the location in
    # the target document to move the value from.
    `from`*: string 


# Web Profile List Object
#   Web profile list
  WebProfileList* = object
    id*: string # Unique ID of the web experience profile. Assigned in response.

    # Name of the web experience profile. Unique only among the profiles for a
    # given merchant.
    name*: string # Required.

    flow_config*: FlowConfig # Parameters for flow configuration.
    input_fields*: InputFields # Parameters for input fields customization.
    presentation*: Presentation # Parameters for style and presentation.




#----------------------------------
# Common Notifications Objects
#----------------------------------

  WebhookErrorStatus* {.pure requiresInit.} = enum
    OPEN # default
    RESOLVED

# Event Type List Object
#   List of Webhooks event-types
  EventTypeList* = object
    event_types*: seq[EventType] # A list of Webhooks event-types


# Webhook List Object
#   List of Webhooks
  WebhookList* = object
    webhooks*: seq[Webhook] # A list of Webhooks


# Event List Object
#   List of Webhooks event resources
  EventList* = object  
    events*: seq[Event] # A list of Webhooks event resources

    # Number of items returned in each range of results. Note that the last
    # results range could have fewer items than the requested number of items.
    count*: int

    links*: Links # HATEOAS links related to this call.


# Error Type List Object
#   List of Webhooks error types
  ErrorTypeList* = object
    error_types*: seq[ErrorType] # A list of Webhooks error-types


# Error List Object
#   List of Webhooks error resources
  ErrorList* = object
    items*: seq[Error] # A list of Webhooks error resources

    # Number of items returned in each range of results. Note that the last
    # results range could have fewer items than the requested number of items.
    total_count*: int

    links*: Links # HATEOAS links related to this call.


# Event Type Object
#   Contains the information for a Webhooks event-type
  EventType* = object
    name*: string # REQUIRED. Unique event-type name.

    # Human readable description of the event-type Assigned in response.
    description*: string


# Webhook Object
#   Represents Webhook resource.
  Webhook* = object
    id*: string # Identifier of the webhook resource. Assigned in response.
    url*: string # REQUIRED. Webhook notification endpoint url.
    event_types*: seq[EventType] # REQUIRED. List of Webhooks event-types.
    links*: Links # HATEOAS links related to this call.


# Event Object
#    Represents a Webhooks event
  Event* = object
    id*: string # Identifier of the Webhooks event resource. Assigned in response.
    create_time*: string # Time the resource was created. Assigned in response.

    # Name of the resource contained in the resource property. Assigned in response.
    resource_type*: string

    # Name of the event type that occurred on the resource to trigger the
    # Webhooks event. Assigned in response.
    event_type*: string

    # A summary description of the event. For example: A successful payment
    # authorization was created. Assigned in response.
    summary*: string

    # XXX (Actual type is `object`. What does that mean?)
    # This contains the resource that is identified by the resource_type property.
    resource*: string # Assigned in response.

    links*: Links # HATEOAS links related to this call.


# Error Type Object
#    Contains information to classify the kind of error happened in the system
  ErrorType* = object
    # Uniquely identify each Webhooks error-type resource Assigned in response.
    id*: string

    name*: string # REQUIRED. Unique error-type name.

    # Human readable description of the error-type Assigned in response.
    description*: string

# Error Object
#   Represents a Webhooks Error
  WebhookError* = object
    id*: string # Identifier of the Webhooks error resource. Assigned in response.
    create_time*: string # Time the resource was created. Assigned in response.
    error_type*: string # REQUIRED. error that resulted in creation of this resource.
    client_id*: string # REQUIRED. client_id for which this error occured
    event_name*: string # REQUIRED. name of the event that is being processed

    # Resource identifier for the resource that should be posted to webhooks endpoint
    resource_identifier*: string

    # The type of the resource pointed to by resource_identifier
    # e.g. authorization, capture, notification, etc.
    resource_type*: string

    # XXX (actual type is `object`. What does that mean?)
    # Most appropriate resource that is available in the context of the error.
    resource*: string

    resource_url*: string # url from which aforementioned resource can be retrieved

    # list of webhook id’s that you are trying to post when this error happened
    webhook_ids*: seq[string]

    debug_id*: string # REQUIRED. correlation id that resulted in this error

    # Detailed description why this error has happened/stack trace of the exception
    description*: string # REQUIRED.

    error_message*: string # REQUIRED. Error message providing description of error

    # Status of the error. Acceptable status at this point are OPEN and RESOLVED.
    status*: WebhookErrorStatus # Default is OPEN 

    links*: Links # HATEOAS links related to this call.


# Simulate Event Object
#   Contains the information for a Webhooks simulator resource
  SimulateEvent* = object
    # Webhook ID. If the webhook ID is not provided, the URL is required.
    webhook_id*: string

    # Webhook endpoint URL. If the URL is not provided, the webhook ID is required.
    url*: string

    # Event-type name. Specify any of the subscribed event types. Provide only
    # one event type for each request.
    event_type*: string # REQUIRED.









#TODO: `T` should be constrained by a `concept`

proc fetch*[T](self: Connection, data_id: string): T =
  let url = if T of Sale:
              "payments/sale"
            elif T of Authorization:
              "payments/authorization"
            elif T of Capture:
              "payments/capture"
            else:
              "payments/refund"
  var sale = new(T)

  self.make_request("GET", url / data_id, nil, "", sale, false)
    # TODO: Transfer JSON data to data object

proc fetchParentPayment*[T](self: Connection, data: T): PaymentObject =
  #TODO: This will instead call the getPayment method when I make it.
  return self.fetch(data.parent_payment)




proc do_refund[T](self: Connection, data: T, ref_req: auto): T =
  var ref_resp = new(T)
  let url = if T of Refund:
              "payments/refund"
            else:
              "payments/capture"

  self.make_request("POST", url / data.id / "refund", ref_req, "", ref_resp, false)

# the Amount must include the PayPal fee paid by the Payee
proc refund(self: Connection, amt: Amount): RefundObject =
  return self.do_refund(&RefundObject{_trans: _trans{Amount: amt}})

proc fullRefund(self: Connection): RefundObject =
  return self.do_refund(&RefundObject{_trans: _trans{Amount: self.Amount}})

