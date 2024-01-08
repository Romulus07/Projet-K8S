resource "azurerm_resource_group" "rg" {
  
}

resource "azapi_resource" "ssh_public_key" {
  type     = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name     = "existing-ssh-key"  # Nom arbitraire pour la clé existante
  location = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id

  properties = {
    publicKey = file("~/.ssh/id_rsa.pub")  # Chemin vers votre clé publique existante
  }
}

output "key_data" {
  value = azapi_resource.ssh_public_key.properties["publicKey"]
}

