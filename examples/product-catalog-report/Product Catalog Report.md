# Product Catalog Report

This example illustrates leveraging the `sap.s4hana.api_product_srv:Client` in Ballerina to report on the product master
data of an S/4HANA system. It reads products together with their descriptions and prints a review of the catalog.

## Overview

The product master is shared by sales, procurement, inventory and manufacturing, so gaps in it show up everywhere: a
product without a description in the customer's language prints as a bare number on an order confirmation, and a product
marked for deletion should not be offered any more. Finding these by hand in a system with thousands of products is slow.

This example pulls a page of products and turns them into a short report. It is read only, so it is safe to run against a
productive tenant.

It demonstrates:

- **Server side paging** with `$top`, so only the requested number of products crosses the wire.
- **Total counts** with `$inlinecount`, which returns how many products match the filter, not just how many are on the
  current page.
- **Projection** with `$select`, so the service returns only the fields the report prints.
- **Reading related entities in one request** with `$expand=to_Description`, instead of one extra call per product for its
  descriptions.
- **Sorting** with `$orderby` and **filtering** with `$filter`, for example to report on a single product type.
- **Decoding OData V2 dates.** The service serialises `Edm.DateTime` as `/Date(<milliseconds since epoch>)/`, which the
  example converts into a readable date.

## Prerequisites

### 1. Setup the S/4HANA API

Refer to the [Setup Guide](https://central.ballerina.io/ballerinax/sap.s4hana.api_product_srv/latest#setup-guide) for the
necessary credentials (hostname, username, password). This API is part of the `Product Integration (SAP_COM_0009)`
communication scenario.

### 2. Configuration

Create a `Config.toml` file in the example directory and provide your S/4HANA credentials:

```toml
# Optional. An OData filter expression, leave it out to report on every product.
productFilter = "ProductType eq 'FERT'"
# Optional. Number of products to pull into the report, 20 by default.
reportSize = 20
# Optional. SAP language key of the descriptions to print, EN by default.
language = "EN"

[s4hanaClientConfig]
hostname = "<unique-id>-api.s4hana.cloud.sap"
username = "<communication-user>"
password = "<communication-user-password>"
```

The `port` and `certPath` fields of `s4hanaClientConfig` only need to be set when the service is not reachable on the
default HTTPS port with a certificate the JVM already trusts, for example when running against the mock server of this
connector.

## Run the example

Execute the following command to run the example:

```bash
bal run
```

The report is printed to the console. With `productFilter = "ProductType eq 'FERT'"`, `reportSize = 5` and
`language = "DE"`:

```
Product          | Type | Group     | Unit | Created    | Description (DE)
-----------------+------+-----------+------+------------+---------------------------
F-10A            | FERT | L004      | PC   | 2023-09-10 | FIN10A, MTS-DDMRP, PD
F-10B            | FERT | L004      | PC   | 2023-09-10 | FIN10B, MTS-DDMRP, PD
F-10E            | FERT | L004      | PC   | 2023-10-31 | -
F-20A            | FERT | L004      | PC   | 2023-09-10 | FIN20A, Lagerfertigung - DDMRP, PD
FG011            | FERT | L004      | PC   | 2023-09-10 | ELEKTRISCHER LÜFTER

Reported on 5 product(s) out of 36 matching the filter.

By product type:
  FERT : 5

Products without a description in DE: 1
  F-10E

Products marked for deletion: 0
```
