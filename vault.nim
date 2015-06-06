
#/*************************************************************
#
#    VAULT:  https://api.paypal.com/v1/vault
#
#PayPal offers merchants a /vault API to store sensitive details like credit card related details.
#
#	You can currently use the /vault API to store credit card details with PayPal instead of
#storing them on your own server. After storing a credit card, you can then pass the credit card
#id instead of the related credit card details to complete a payment.
#
#	For more information, learn about using the /vault API to `store a credit card`.
#https://developer.paypal.com/webapps/developer/docs/integration/direct/store-a-credit-card/
#
#	Direct credit card payment and related features are `restricted in some countries`.
#https://developer.paypal.com/webapps/developer/docs/integration/direct/rest_api_payment_country_currency_support/#direct-credit-card-payments
#
#
#**************************************************************/
#
#
#//	RawData		[]byte `json:"-"`
