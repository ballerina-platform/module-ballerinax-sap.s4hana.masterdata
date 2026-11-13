// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.org).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;
import ballerina/lang.regexp;
import ballerina/time;
import ballerinax/sap.s4hana.api_product_srv as product;

configurable S4HanaClientConfig s4hanaClientConfig = ?;

// An OData filter expression restricting the report, for example "ProductType eq 'FERT'" to report
// on finished products only. Leave it empty to report on every product.
configurable string productFilter = "";

// Number of products to pull into the report.
configurable int reportSize = 20;

// Language of the product descriptions to print, as an SAP language key such as "EN" or "DE".
configurable string language = "EN";

final product:Client productClient = check initProductClient();

public function main() returns error? {
    product:ListA_ProductsQueries queries = {
        \$top: reportSize,
        // Ask the server for the total number of matching products, not just this page.
        \$inlinecount: "allpages",
        \$orderby: ["Product"],
        // Only pull the fields the report actually prints, plus the descriptions.
        \$select: [
            "Product",
            "ProductType",
            "ProductGroup",
            "BaseUnit",
            "CreationDate",
            "IsMarkedForDeletion",
            "to_Description"
        ],
        // Read the descriptions in the same request instead of one extra call per product.
        \$expand: ["to_Description"]
    };
    if productFilter.trim() != "" {
        queries.\$filter = productFilter;
    }

    product:CollectionOfA_ProductWrapper response = check productClient->listA_Products(queries = queries);

    product:A_Product[] products = response.d?.results ?: [];
    if products.length() == 0 {
        io:println("No products matched the report criteria.");
        return;
    }

    ProductSummary[] summaries = from product:A_Product entry in products
        select {
            product: entry?.Product ?: "-",
            productType: entry?.ProductType ?: "-",
            productGroup: entry?.ProductGroup ?: "-",
            baseUnit: entry?.BaseUnit ?: "-",
            createdOn: toDisplayDate(entry?.CreationDate),
            description: descriptionIn(entry, language),
            markedForDeletion: entry?.IsMarkedForDeletion ?: false
        };

    printReport(summaries, response.d?.__count);
}

isolated function printReport(ProductSummary[] summaries, string? totalCount) {
    io:println(string `Product          | Type | Group     | Unit | Created    | Description (${language})`);
    io:println("-----------------+------+-----------+------+------------+---------------------------");
    foreach ProductSummary summary in summaries {
        io:println(string `${pad(summary.product, 16)} | ${pad(summary.productType, 4)}`
                + string ` | ${pad(summary.productGroup, 9)} | ${pad(summary.baseUnit, 4)}`
                + string ` | ${pad(summary.createdOn, 10)} | ${summary.description ?: "-"}`);
    }

    io:println(string `
Reported on ${summaries.length()} product(s)`
            + (totalCount is string ? string ` out of ${totalCount} matching the filter.` : "."));

    // Break the report down by product type, for example SERV for services or FERT for finished products.
    map<int> countByType = {};
    foreach ProductSummary summary in summaries {
        countByType[summary.productType] = (countByType[summary.productType] ?: 0) + 1;
    }
    io:println("\nBy product type:");
    foreach [string, int] [productType, count] in countByType.entries() {
        io:println(string `  ${pad(productType, 4)} : ${count}`);
    }

    // Products without a description in the report language show up as bare numbers in documents
    // printed in that language, so they are worth fixing in the master data.
    string[] withoutDescription = from ProductSummary summary in summaries
        where summary.description is ()
        select summary.product;
    io:println(string `
Products without a description in ${language}: ${withoutDescription.length()}`);
    foreach string productId in withoutDescription {
        io:println(string `  ${productId}`);
    }

    string[] markedForDeletion = from ProductSummary summary in summaries
        where summary.markedForDeletion
        select summary.product;
    io:println(string `
Products marked for deletion: ${markedForDeletion.length()}`);
    foreach string productId in markedForDeletion {
        io:println(string `  ${productId}`);
    }
}

# Picks the description of a product in one language from its expanded descriptions.
#
# + entry - Product read with `$expand=to_Description`
# + languageKey - SAP language key, such as `EN`
# + return - The description, or `()` if the product has none in that language
isolated function descriptionIn(product:A_Product entry, string languageKey) returns string? {
    product:A_ProductDescription[] descriptions = entry?.to_Description?.results ?: [];
    foreach product:A_ProductDescription description in descriptions {
        if description?.Language == languageKey {
            return description?.ProductDescription;
        }
    }
    return ();
}

# Converts an OData V2 `Edm.DateTime` value into a readable date.
#
# The service serialises dates as `/Date(<milliseconds since epoch>)/`, so the raw value is not
# directly presentable.
#
# + odataDate - Raw date value as returned by the service
# + return - The date as `yyyy-MM-dd`, or the untouched input if it cannot be parsed
isolated function toDisplayDate(string? odataDate) returns string {
    if odataDate is () {
        return "-";
    }
    regexp:Groups? groups = re `Date\((-?\d+)`.findGroups(odataDate);
    if groups is () || groups.length() < 2 {
        return odataDate;
    }
    regexp:Span? milliseconds = groups[1];
    if milliseconds is () {
        return odataDate;
    }
    int|error epochMilliseconds = int:fromString(milliseconds.substring());
    if epochMilliseconds is error {
        return odataDate;
    }
    time:Civil civil = time:utcToCivil([epochMilliseconds / 1000, 0]);
    return string `${civil.year}-${pad2(civil.month)}-${pad2(civil.day)}`;
}

isolated function pad2(int value) returns string => value < 10 ? string `0${value}` : value.toString();

isolated function pad(string value, int width) returns string {
    string padded = value;
    while padded.length() < width {
        padded += " ";
    }
    return padded;
}

# Builds the connector client, adding a trusted certificate only when one is configured.
#
# + return - The initialized client, or an error if initialization failed
function initProductClient() returns product:Client|error {
    product:ConnectionConfig config = {
        auth: {
            username: s4hanaClientConfig.username,
            password: s4hanaClientConfig.password
        }
    };
    string? certPath = s4hanaClientConfig?.certPath;
    if certPath is string {
        config.secureSocket = {cert: certPath};
    }
    return new (config, s4hanaClientConfig.hostname, s4hanaClientConfig.port);
}
