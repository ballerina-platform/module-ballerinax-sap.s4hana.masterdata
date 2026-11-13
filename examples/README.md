# Examples

The S/4HANA Master Data Ballerina connectors provide practical examples illustrating usage in various scenarios. Explore
these [examples](https://github.com/ballerina-platform/module-ballerinax-sap.s4hana.masterdata/tree/main/examples).

1. [Product Catalog Report](https://github.com/ballerina-platform/module-ballerinax-sap.s4hana.masterdata/tree/main/examples/product-catalog-report) -
   Reports on the product master data, using the OData query options of the `sap.s4hana.api_product_srv:Client` to page,
   filter, sort and project the result and to read each product's descriptions in the same request. It lists the
   products without a description in a given language and those marked for deletion. It is read only, so it is safe to
   run against a productive tenant.

## Prerequisites

Each example includes detailed steps.

## Running an Example

Execute the following commands to build an example from the source:

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```

## Building the Examples with the Local Module

**Warning**: Due to the absence of support for reading local repositories for single Ballerina files, the Bala of the
module is manually written to the central repository as a workaround. Consequently, the bash script may modify your
local Ballerina repositories.

Execute the following commands to build all the examples against the changes you have made to the module locally:

* To build all the examples:

    ```bash
    ./build.sh build
    ```

* To run all the examples:

    ```bash
    ./build.sh run
    ```