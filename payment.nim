import types


# Pagination
#  Assuming `start_time`, `start_index` and `start_id` are mutually exclusive
#  ...going to treat them that way anyhow until I understand better.

# I'm going to ignore `start_index` for now since I don't see its usefulness

proc getAll*(self: Payments, size: int, sort_by: sort_by_i, sort_order: sort_order_i, time_range: ...time.Time): PaymentBatcher =
  if size < 0:
    size = 0
  elif size > 20:
    size = 20

  var qry = fmt.Sprintf("?sort_order=%s&sort_by=%s&count=%d", sort_by, sort_order, size)

  if len(time_range) > 0:
    if time_range[0].IsZero() == false:
      qry = fmt.Sprintf("%s&start_time=%s", qry, time_range[0].Format(time.RFC3339))

    if len(time_range) > 1 && time_range[1].After(time_range[0]):
      qry = fmt.Sprintf("%s&end_time=%s", qry, time_range[1].Format(time.RFC3339))

  return PaymentBatcher(
    base_query: qry,
    next_id:    "",
    done:       false,
    connection: self.connection,
  )

#/****************************************
#
#  PaymentBatcher
#
#Manages paginated requests for Payments
#
#*****************************************/


proc IsDone (self: PaymentBatcher): bool =
  return self.done

# TODO: Should `.Next()` take an optional filter function?
proc Next (self:var PaymentBatcher): ([]*PaymentObject, error) =
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

proc Get(self: Payments, payment_id: string): (*PaymentObject, error) =
  var pymt = new(PaymentObject)
  var err = self.connection.make_request("GET", "payments/payment/"+payment_id,
                                          nil, "", pymt, false)
  if err.isNil:
    return pymt, nil
  else:
    return nil, err

proc create(self: Payments, meth: PaymentMethod, return_url,cancel_url: string):
                                                    (*PaymentObject, error) =

  if method == PayPal:
    # Make sure we're still authenticated. Will refresh if not.
    var err = self.connection.authenticate()
    if not err.isNil:
      return nil, err

    return &PaymentObject{
      PaymentExecutor: PaymentExecutor {
        payments:     self,
      },
      Intent: Sale,
      Redirect_urls: redirects{
        Return_url: return_url,
        Cancel_url: cancel_url,
      },
      Payer: payer{
        Payment_method: method.payment_method(), # PayPal
      },
      Transactions: make([]*transaction, 0),
    }, nil
  }
  return nil, nil

proc ParseRawData(self: Payments, rawdata: string): PaymentObject =
  var po PaymentObject
  var err = json.Unmarshal(rawdata, &po)
  if not err.isNil:
    return nil
  return &po

proc Execute(self: Payments, pymt: PaymentFinalizer, req: *http.Request): error =
  var query = req.URL.Query()

  # TODO: Is this right? Does URL.Query() ever return nil?
  if query.isNil:
    return fmt.Errorf("Attempt to execute a payment that has not been approved")

  var payerid = query.Get("PayerID")
  if payerid == "":
    payerid = pymt.GetPayerID()
    if payerid == "":
      return fmt.Errorf("PayerID is missing\n")

  if pymt.isNil:
    return fmt.Errorf("Payment Object is missing\n")

  var pymtid = pymt.GetId()
  if pymtid == "":
    return fmt.Errorf("Payment ID is missing\n")

  var pathname = path.Join("payments/payment", pymtid, "execute")

  var err = self.connection.make_request("POST", pathname, `{"payer_id":"`+payerid+`"}`, "execute_", pymt, false)
  if not err.isNil:
    return err

  if pymt.GetState() != Approved:
#/*
#    var s, err = json.Marshal(pymt)
#    if err != nil {
#      return fmt.Errorf("JSON marshal error\n")
#    }
#    fmt.Println(string(s))
#*/
    return fmt.Errorf("Payment with ID %q for payer %q was not approved\n", pymtid, payerid)

  return nil

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

proc getState*(self: PaymentObject): State =
  return self.State

proc getId*(self: PaymentObject): string =
  return self.Id

proc getPayerID*(self: PaymentObject): string =
  if not self.isNil and self.Payer.Payer_info != nil:
    return self.Payer.Payer_info.Payer_id
  return ""

proc MakeExecutor*(self: PaymentObject): PaymentExecutor =
  return &PaymentExecutor{
    Id: self.Id,
    State: self.State,
    payments: self.payments,
  }

proc addTransaction*(self: PaymentObject, trans: Transaction) =
  var t = transaction{
    Amount: Amount{
      Currency: trans.Currency.currency_type(),
      Total:    trans.Total,
    },
    Description: trans.Description,
  }
  if not trans.Details.isNil:
    t.Amount.Details = &Details{
      Subtotal: trans.Details.Subtotal,
      Tax:      trans.Details.Tax,
      Shipping: trans.Details.Shipping,
    }
    #  Fee: "0",  # This field is only for paypal response data
  }

  if not trans.item_list.isNil:
    var list = *trans.item_list
    t.Item_list = &list

  if not trans.ShippingAddress.isNil:
    if t.Item_list.isNil:
      t.Item_list = new(item_list)
    t.Item_list.Shipping_address = trans.ShippingAddress
  self.Transactions = append(self.Transactions, &t)

# TODO: The tkn parameter is ignored, but should send a query string parameter `token=tkn`
proc authorize*(self: PaymentObject, tkn: string): (to string, code int, err error) =

  err = self.payments.connection.make_request("POST", "payments/payment", self, "send_", self, false)

  if err.isNil:
    switch self.State {
    case Created:
      # Set url to redirect to PayPal site to begin approval process
      to, _ = self.Links.get("approval_url")
      code = 303
    default:
      # otherwise cancel the payment and return an error
      err = UnexpectedResponse
    }

  return to, code, err

proc execute*(self: PaymentObject, req: *http.Request): error =
  return self.payments.Execute(self, req)

proc addItem*(t: Transaction, qty: uint, price: float64, curr: currency_type_i, name, sku: string) =
  if t.item_list.isNil:
    t.item_list = new(item_list)
  t.item_list.Items = append(t.item_list.Items, &item{
    Quantity: qty,
    Name:     name,
    Price:    price,
    Currency: curr.currency_type(),
    Sku:      sku,
  })

# TODO: I'm returning a list of Sale objects because every payment can have multiple transactions.
#    I need to find out why a payment can have multiple transactions, and see if I should eliminate that in the API
#    Also, I need to find out why `related_resources` is an array. Can there be more than one per type?
proc getSale*(self: PaymentObject): seq[SaleObject] =
  var sales = []*SaleObject{}
  for transaction in self.Transactions:
    for related_resource in transaction.Related_resources:
      if not related_resource.Sale.isNil:
        sales.add(related_resource.Sale)
  return sales


proc get(l links, s string): (string, string) =
  for i, _ in l:
    if l[i].Rel == s:
      return l[i].Href, l[i].Method
  return "", ""


