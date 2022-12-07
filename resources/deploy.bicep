// ------
// Scopes
// ------

targetScope = 'resourceGroup'

// ---------
// Parameters
// ---------

param location string
param projectName string
param owner string

// ---------
// Variables
// ---------

// var location = resourceGroup().location

// ---------
// Resources
// ---------

// example of how to create a resource group in the main
// // https://docs.microsoft.com/en-us/azure/templates/microsoft.resources/resourcegroups?tabs=bicep
// resource resource_group 'Microsoft.Resources/resourceGroups@2021-01-01' = {
//   name: '${projectName}-${uniqueResourceGroupName_var}'
//   location: location
//   tags: {
//     ProjectName: projectName
//     Environment: environmentType
//     Criticality: businessCriticality
//     Owner: owner
//     Location: location
//   }
//   // properties:{
//   // }
// }

// ---------
// Modules
// ---------

// this format can be re-used to deploy multiple sub-module resource files
module function 'functions.bicep' = {
  name: 'beard-function'
  // scope: resource_group
  params: {
    projectName: projectName
    location: location
    owner: owner
  }
}

// ---------
// Outputs
// ---------

// To reference module outputs
output storageAccountName string = function.outputs.storageAccountName
output storageAccountID string = function.outputs.storageAccountID

output containerName string = function.outputs.containerName
output containerID string = function.outputs.containerID

output tableName string = function.outputs.tableName
output tableID string = function.outputs.tableID

// output keyVaultName string = function.outputs.keyVaultName
// output keyVaultID string = function.outputs.keyVaultID

output planName string = function.outputs.planName
output planId string = function.outputs.planId

output functionAppName string = function.outputs.functionAppName
output functionAppID string = function.outputs.functionAppID

output appInsightsName string = function.outputs.appInsightsName
output appInsightsID string = function.outputs.appInsightsID

output saPermName string = function.outputs.saPermName
output saPermID string = function.outputs.saPermID

output conPermName string = function.outputs.conPermName
output conPermID string = function.outputs.conPermID

// output tablePermName string = function.outputs.tablePermName
// output tablePermID string = function.outputs.tablePermID
