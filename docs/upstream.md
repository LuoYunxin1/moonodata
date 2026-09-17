# Upstream mapping

Port basis: SAP/python-pyodata (Apache-2.0) plus OASIS OData 4.0 URL Conventions and JSON Format.

| Area | In this port | Out of scope |
| --- | --- | --- |
| Resource path | entity set, key, nav, `$count`/`$value`/`$ref`/`$metadata` | path templating, type-cast segments |
| Query options | `$filter` `$select` `$expand` `$orderby` `$top` `$skip` `$count` `$search` `$format` | `$apply`, `$compute`, delta tokens |
| JSON | `@odata.context`, `value`, `@odata.count`, error object | JSON verbose 2.0, delta payloads |
| EDM | EntityType, Property, PropertyRef, EntitySet | functions/actions, annotations, full CSDL 4.01 |
| Transport | none | HTTP client, auth, batch `/$batch` |
