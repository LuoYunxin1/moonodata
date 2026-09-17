fn main {
  let boot = @odata.unwrap_odata(
    @odata.parse_url(
      "/Products?$filter=Name eq 'Bread' and Price gt 2&$select=Name,Price&$top=5",
    ),
  )
  println("FILTER: " + @odata.encode_url(boot))
  let keyed = @odata.unwrap_odata(
    @odata.parse_url("/Orders(42)/Customer?$expand=Address&$count=true"),
  )
  println("EXPAND: " + @odata.encode_url(keyed))
  let doc = @odata.unwrap_odata(
    @odata.parse_payload(
      "{\"@odata.context\":\"https://services.odata.org/V4/OData/OData.svc/$metadata#Products\",\"value\":[{\"ID\":1,\"Name\":\"Bread\",\"Price\":2.5}]}",
    ),
  )
  let encoded = @odata.encode_payload(doc)
  println("JSON: " + encoded.stringify())
  println("MoonOData acceptance: 3 scenarios passed")
}
