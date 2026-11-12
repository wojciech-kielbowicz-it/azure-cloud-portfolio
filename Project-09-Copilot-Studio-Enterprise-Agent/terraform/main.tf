# Obtaining existing AI Spoke Resource Group & AI Services Account -> Project-07
data "azurerm_resource_group" "rg_spoke_ai" {
  name = "rg-spoke-ai-data"
}

data "azurerm_resources" "ai_services" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  type                = "Microsoft.CognitiveServices/accounts"
}

# Deploy GPT-6.1-terra Model for Enterprise Copilot Reasoning
resource "azurerm_cognitive_deployment" "gpt_copilot" {
  name                   = "gpt-copilot-enterprise"
  cognitive_account_id   = data.azurerm_resources.ai_services.resources[0].id
  version_upgrade_option = "OnceCurrentVersionExpired"

  model {
    format  = "OpenAI"
    name    = "gpt-6.1-terra" # AI Model
    version = "2026-10-26"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }
}

# Deploy Text-Embedding Model for Vectorizing ADLS Gen2 Documents in AI Search
resource "azurerm_cognitive_deployment" "text_embedding" {
  name                   = "text-embedding-ada-002"
  cognitive_account_id   = data.azurerm_resources.ai_services.resources[0].id
  version_upgrade_option = "OnceCurrentVersionExpired"

  model {
    format  = "OpenAI"
    name    = "text-embedding-ada-002" # Model
    version = "2"
  }

  sku {
    name     = "Standard"
    capacity = 10
  }

  depends_on = [azurerm_cognitive_deployment.gpt_copilot]
}
