param keyVaultName string = 'beard-key-vault'
param functionappId string
param storageSecValue string
//'DefaultEndpointsProtocol=https;AccountName=${storageaccount.name};AccountKey=${listKeys(storageaccount.id,storageaccount.apiVersion).keys[1].value}'

resource keyvault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource keyvaultAccess 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  name: '${keyvault.name}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: reference(functionappId, '2022-03-01', 'full').identity.principalId
        // applicationId: 'string'
        permissions: {
          // keys: [
          //   'string'
          // ]
          secrets: [
            'get'
            'list'
          ]
          // certificates: [
          //   'string'
          // ]
          // storage: [
          //   'string'
          // ]
        }
      }
    ]
  }
}

resource storageSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyvault.name}/storageSecret'
  properties: {
    value: storageSecValue
    contentType: 'string'
    attributes: {
      enabled: true
      // notBefore: '2021-12-31T23:59:59Z'
      // expires: '2021-12-31T23:59:59Z'
      // created: '2021-12-31T23:59:59Z'
      // updated: '2021-12-31T23:59:59Z'
    }
    // tags: {}
  }
}
// https://dev.to/dazfuller/azure-bicep-deploy-function-apps-with-keyvault-references-36o1

// Key Vault Secrets User - https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles

output StorageSecretName string = storageSecret.name
