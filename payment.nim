import addtl_procs
import extras
import marshal
import pay
import times
import types


proc newPayment*(self:var Connection, `method`: PaymentMethod,
                                returnUrl, cancelUrl: string): PaymentRequest =
  ## Creates a new Payment.
  ## Use `.add()` to add Transactions to the Payment.
  ## When ready, use `.authorize()` to gain payment authorization and
  ## `.execute()` to execute the final, authorized payment.
  if `method` == PaymentMethod.PayPal:
    # Make sure we're still authenticated. Will refresh if not.
    self.authenticate()

    result = PaymentRequest(
      intent: Intent.Sale,
      redirect_urls: RedirectURLs (
        return_url: return_url,
        cancel_url: cancel_url,
      ),
      payer: PayerBase(
        payment_method: `method`, # PayPal
      ),
      transactions: @[],
    )


# TODO: Because some fields are only valid when `payment_method` is `paypal`, I
# should really have separate constructors for paypal vs non-paypal transactions.
#
## A PayPal payment sends a list of transactions. Use `newTransaction()` to
## create a single transaction and then its `addItem()` method to add amounts.
proc newTransaction*(currency: CurrencyType,
                     shipping: float64,
                     handling: float64,
                     insurance: float64,
                     shippingDiscount: float64,
                     description: string,
                     invoiceNumber: string,
                     custom: string,
                     softDescriptor: string,
                     address: ShippingAddress,
                     ): Transaction =
  # Total equals sum of subtotal, shipping, tax, handling and insurance minus
  # the shippingDiscount.
  result.amount = TransactionAmount(
    currency: currency,
    # total: calculated from `details` fields
    details: TransactionDetails(
      # tax: calculated from `item_list` members
      # subtotal: calculated from `item_list` members
      shipping: shipping,
      handling_fee: handling,
      insurance: insurance,
      shipping_discount: shippingDiscount,

      # This field would be under `item_list`, except that it's needed for the
      # `tax` and `subtotal` calculations, so it's here instead with an
      # `item_list` proc in its place on the `Transaction` object.
      item_list: ItemList(
        shipping_address: address,
        items: @[],
      )
    ),
  )
  result.invoice_number = invoiceNumber
  result.custom = custom
  result.soft_descriptor = softDescriptor


## Add an individual amount to a Transaction. This is similar to a line item on
## an invoice.
## The currency type is whatever was assigned to the Transaction object.
proc addItem*(self:var Transaction, quantity: Natural,
                                    price, tax: float64,
                                    name, description, sku: string) =
  self.amount.details.item_list.items.add(Item(quantity: quantity,
                                                name: name,
                                                price: price,
                                                sku: sku,
                                                currency: self.amount.currency,
                                                description: description,
                                                tax: tax))

# This is used because the `item_list` field of the `Transaction` object is
# actually held in the `TransactionDetails` held by `TransactionAmount`.
proc item_list*(self: Transaction): ItemList =
  self.amount.details.item_list

proc tax(self:TransactionDetails): float64 =
  for item in self.item_list.items:
    result += item.tax

proc subtotal(self:TransactionDetails): float64 =
  for item in self.item_list.items:
    result += float64(item.quantity) * item.price


proc total(self: TransactionAmount): float64 =
  result = (self.details.tax() +
            self.details.subtotal() +
            self.details.shipping +
            self.details.handling_fee +
            self.details.insurance) - self.details.shipping_discount

proc total(self: Amount): float64 =
  result = (self.details.tax +
            self.details.subtotal +
            self.details.shipping +
            self.details.handling_fee +
            self.details.insurance) - self.details.shipping_discount




proc add*(self:var PaymentRequest, trans: varargs[Transaction]) =
  ## Add `Transaction` objects before making the request.
  for t in trans:
    self.transactions.add(t)


proc send*(self:var Connection, pymtReq: PaymentRequest): Link =
  #       When there's a valid response, redirect the user to the given
  #       "approval_url".
  var pymtResp = pymtReq.toSub(Payment)

  self.make_request(RType.PaypalPayment, pymtReq, pymtResp)

  if pymtResp.state == PaymentState.created:
    # Return URL info for the user to redirect to for approval
    return pymtResp.links.get("approval_url")
  else:
    raise new Exception # TODO: UnexpectedResponse


proc execute*(self: Connection, query: string) =
  # TODO: complete this method. It's all fictional right now.
  let query = query.parse()

  if query.isNil:
    raise new Exception # Query params not valid

  var payerid = query.Get("PayerID")
  if payerid == "":
    raise new Exception # Query params not valid

  if pymt.isNil:
    return fmt.Errorf("Payment Object is missing\n")

  var pathname = "payments/payment" / pymtid / "execute"

  self.make_request("POST", pathname, "{\"payer_id\":\"" & payerid & "\"}",
                                                      "execute_", pymt, false)

  if pymt.GetState() != Approved:
#/*
#    var s, err = json.Marshal(pymt)
#    if err != nil {
#      return fmt.Errorf("JSON marshal error\n")
#    }
#    fmt.Println(string(s))
#*/
    raise new Exception # Payment not approved


# Pagination
#  Assuming `start_time`, `start_index` and `start_id` are mutually exclusive
#  ...going to treat them that way anyhow until I understand better.

# I'm going to ignore `start_index` for now since I don't see its usefulness

proc getAll*(self: Connection, size: range[0..20], sortBy: SortBy,
            sortOrder: SortOrder, timeRange: varargs[Time]): PaymentBatcher =

  var qry = fmt.Sprintf("?sort_order=%s&sort_by=%s&count=%d", sort_by, sort_order, size)

  if len(time_range) > 0:
    if time_range[0].IsZero() == false:
      qry = fmt.Sprintf("%s&start_time=%s", qry, time_range[0].Format(time.RFC3339))

    if len(time_range) > 1 and time_range[1].After(time_range[0]):
      qry = fmt.Sprintf("%s&end_time=%s", qry, time_range[1].Format(time.RFC3339))

  return PaymentBatcher(
    base_query: qry,
    next_id:    "",
    done:       false,
    connection: connection,
  )





#/****************************************
#
#  PaymentBatcher
#
#Manages paginated requests for Payments
#
#*****************************************/


proc isDone* (self: PaymentBatcher): bool =
  return self.done

# TODO: Should `.next()` take an optional filter function?
proc next (self:var PaymentBatcher): ([]Payment, error) =
  if self.done:
    return nil, ErrNoResults

  var pymt_list = new(payment_list)
  var qry = self.base_query

  if self.next_id != "":
    qry = fmt.Sprintf("%s&start_id=%s", qry, self.next_id)

  var err = self.connection.make_request("GET", "payments/payment"+qry, nil,
                                          "", pymt_list, false)
  if not err.isNil:
    return nil, err

  if pymt_list.Count == 0:
    self.done = true
    self.next_id = ""
    return nil, ErrNoResults

  self.next_id = pymt_list.Next_id

  if self.next_id == "":
    self.done = true

  return pymt_list.Payments, nil

# These provide a way to both get and set the `next_id`.
# This gives the ability to cache the ID, and then set it in a new Batcher.
# Useful if a session is not desired or practical

proc getNextId*(self: PaymentBatcher): string =
  return self.next_id

proc setNextId*(self:var PaymentBatcher, id: string) =
  self.next_id = id



proc parseRawData*(self: Payments, rawdata: string): Payment =
  var po: Payment
  var err = json.Unmarshal(rawdata, &po)
  if not err.isNil:
    return nil
  result = &po


# TODO: Should this hold the `execute` path so that it doesn't need to be constructed in `Execute()`?
proc getState*(self: PaymentExecutor): State =
  return self.State

proc getId*(self: PaymentExecutor): string =
  return self.Id

proc getPayerID*(self: PaymentExecutor): string =
  return self.PayerID

proc execute*(self: PaymentExecutor, r: *http.Request): error =
  return self.payments.Execute(self, r)

#/***************************
#
#  Payment object methods
#
#***************************/

proc getState*(self: Payment): State =
  return self.State

proc getId*(self: Payment): string =
  return self.Id

proc getPayerID*(self: Payment): string =
  if not self.isNil and self.Payer.Payer_info != nil:
    return self.Payer.Payer_info.Payer_id
  return ""

proc makeExecutor*(self: Payment): PaymentExecutor =
  return &PaymentExecutor{
    id*: self.Id,
    state*: self.State,
    payments: self.payments,
  }


proc addItem*(t: Transaction, qty: uint, price: float64, curr: CurrencyType,
                                                          name, sku: string) =
  if t.item_list.isNil:
    t.item_list = new(item_list)

  t.item_list.items.add(Item(
    quantity: qty,
    name:     name,
    price:    price,
    currency: curr.currency_type(),
    sku:      sku,
  ))

# TODO: I'm returning a list of Sale objects because every payment can have multiple transactions.
#    I need to find out why a payment can have multiple transactions, and see if I should eliminate that in the API
#    Also, I need to find out why `related_resources` is an array. Can there be more than one per type?
proc getSale*(self: Payment): seq[SaleObject] =
  var sales = []*SaleObject{}
  for transaction in self.Transactions:
    for related_resource in transaction.related_resources:
      if not related_resource.sale.isNil:
        sales.add(related_resource.Sale)
  return sales



