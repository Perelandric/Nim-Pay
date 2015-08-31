import types

proc get*(self: Links, kind: string): Link =
  for link in self:
    if link.rel == kind:
      return link

# Refund procs
# (none so far)



# Sale procs

proc doRefund(self: Connection, sale: Sale, ref_req: auto): RefundObject =
  var ref_resp = new(RefundObject)
  var err = self.make_request("POST", "payments/sale/"+sale.Id+"/refund",
                                                  ref_req, "", ref_resp, false)
  # TODO: Transfer JSON data to refund object
  return ref_resp

proc refundSale*(self: Connection, sale: Sale, amt: Amount): RefundObject =
  return self.do_refund(sale, &RefundObject{_trans: _trans{Amount: amt}})

proc fullRefund*(self: Connection, sale: SaleObject): RefundObject =
  return self.do_refund(`{}`)



# Authorization procs

proc (self *AuthorizationObject) Capture(amt *Amount, is_final bool) (*CaptureObject, error) {
  var capt_req = &CaptureObject{
    _trans: _trans{
      Amount: *amt,
    },
    Is_final_capture: is_final,
  }
  var capt_resp = new(CaptureObject)

  var err = self.authorizations.connection.make_request("POST",
    "payments/authorization/"+self.Id+"/capture",
    capt_req, "", capt_resp, false)
  if err != nil {
    return nil, err
  }
  return capt_resp, nil
}

proc (self *AuthorizationObject) Void() (*AuthorizationObject, error) {
  var void_resp = new(AuthorizationObject)

  var err = self.authorizations.connection.make_request("POST",
    "payments/authorization/"+self.Id+"/void",
    nil, "", void_resp, false)
  if err != nil {
    return nil, err
  }
  return void_resp, nil
}

# TODO: Since only PayPal authorizations can be re-authorized, should I add a check
#      for this? Or should I just let the error come back from the server?
proc (self *AuthorizationObject) ReauthorizeAmount(amt *Amount) (*AuthorizationObject, error) {
  var auth_req = new(AuthorizationObject)
  if amt == nil {
    auth_req.Amount = self.Amount
  } else {
    auth_req.Amount = *amt
  }
  var auth_resp = new(AuthorizationObject)

  var err = self.authorizations.connection.make_request("POST",
    "payments/authorization/"+self.Id+"/reauthorize",
    auth_req, "", auth_resp, false)
  if err != nil {
    return nil, err
  }
  return auth_resp, nil
}

proc (self *AuthorizationObject) Reauthorize() (*AuthorizationObject, error) {
  return self.ReauthorizeAmount(nil)
}
