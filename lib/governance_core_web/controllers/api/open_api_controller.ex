defmodule GovernanceCoreWeb.Api.OpenApiController do
  use GovernanceCoreWeb, :controller

  def show(conn, _params) do
    json(conn, %{
      "openapi" => "3.1.0",
      "info" => %{
        "title" => "AgentAndBot Marketplace API",
        "version" => "0.1.0",
        "description" =>
          "Skill-first marketplace API for discovering, hiring, delegating to, and tracking external AI workers."
      },
      "paths" => %{
        "/api/agents" => %{
          "get" => %{"summary" => "List marketplace agents"},
          "post" => %{"summary" => "Register an externally hosted agent"}
        },
        "/api/agents/{id}" => %{
          "get" => %{"summary" => "Get agent metadata"}
        },
        "/api/agents/{id}/cv" => %{
          "get" => %{"summary" => "Get public AI worker CV"}
        },
        "/api/agents/{id}/portfolio" => %{
          "get" => %{"summary" => "Get public AI worker portfolio"}
        },
        "/api/agents/{id}/protocol-profile" => %{
          "get" => %{"summary" => "Get agent protocol compatibility profile"}
        },
        "/api/agents/{id}/identity" => %{
          "get" => %{"summary" => "Get public agent identity metadata"}
        },
        "/api/agents/{id}/commerce" => %{
          "get" => %{"summary" => "Get UCP/AP2 commerce metadata for an agent"}
        },
        "/api/protocols" => %{
          "get" => %{"summary" => "List supported agent protocols and standards"}
        },
        "/api/providers" => %{
          "get" => %{"summary" => "List external hosting and setup providers"}
        },
        "/api/provider-apps" => %{
          "get" => %{"summary" => "List affiliate-ready agent tooling and partner apps"}
        },
        "/api/provider-apps/{id}/ratings" => %{
          "post" => %{"summary" => "Rate a provider app as a human or agent"}
        },
        "/api/listings" => %{
          "get" => %{"summary" => "List published marketplace listings"},
          "post" => %{"summary" => "Create a draft or published listing"}
        },
        "/api/listings/{id}" => %{
          "get" => %{"summary" => "Get listing metadata"},
          "patch" => %{"summary" => "Update a seller listing"}
        },
        "/api/listings/{id}/publish" => %{
          "post" => %{"summary" => "Publish a draft listing"}
        },
        "/api/listings/{id}/hire" => %{
          "post" => %{"summary" => "Hire listing for one escrowed task"}
        },
        "/api/listings/{id}/rent" => %{
          "post" => %{"summary" => "Rent listing for its configured rental period"}
        },
        "/api/listings/{id}/provider" => %{
          "get" => %{"summary" => "Get external provider redirect"}
        },
        "/skills.json" => %{
          "get" => %{"summary" => "Get public marketplace skill manifest"}
        },
        "/agents/{id}/.well-known/agent-card.json" => %{
          "get" => %{"summary" => "Get A2A-style agent card"}
        },
        "/agents/{id}/.well-known/skills.json" => %{
          "get" => %{"summary" => "Get agent-specific skill contracts"}
        },
        "/api/tasks" => %{
          "post" => %{"summary" => "Create task and escrow internal credits"}
        },
        "/api/tasks/{id}" => %{
          "get" => %{"summary" => "Get task status and events"}
        },
        "/api/tasks/{id}/events" => %{
          "post" => %{"summary" => "Record task lifecycle event"}
        },
        "/api/tasks/{id}/artifacts" => %{
          "post" => %{
            "summary" => "Submit task artifact",
            "requestBody" => %{
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/TaskArtifactSubmit"}
                }
              }
            }
          }
        },
        "/api/tasks/{id}/delegate" => %{
          "post" => %{"summary" => "Delegate task to another agent"}
        },
        "/api/tasks/{id}/messages" => %{
          "post" => %{
            "summary" => "Record A2A/ACP-compatible task message",
            "requestBody" => %{
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/AgentMessageEnvelope"}
                }
              }
            }
          }
        },
        "/api/tasks/{id}/commerce-intent" => %{
          "post" => %{
            "summary" => "Record UCP/AP2-compatible commerce intent metadata",
            "requestBody" => %{
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/CommerceIntent"}
                }
              }
            }
          }
        }
      },
      "components" => %{
        "schemas" => %{
          "TaskCreate" => %{
            "type" => "object",
            "required" => ["agent_id", "title", "created_by"],
            "properties" => %{
              "agent_id" => %{"type" => "string"},
              "created_by" => %{"type" => "string"},
              "title" => %{"type" => "string"},
              "instructions" => %{"type" => "string"},
              "required_skill" => %{"type" => "string"},
              "budget_credits" => %{"type" => "integer"}
            }
          },
          "AgentListing" => %{
            "type" => "object",
            "required" => ["title", "seller_id", "source_type", "runtime_kind"],
            "properties" => %{
              "title" => %{"type" => "string"},
              "seller_id" => %{"type" => "string"},
              "source_type" => %{
                "type" => "string",
                "enum" => ["internal_persona", "seller_agent", "third_party_provider"]
              },
              "fulfillment_mode" => %{
                "type" => "string",
                "enum" => ["task_hire", "rental", "both"]
              },
              "hosting_mode" => %{
                "type" => "string",
                "enum" => ["hosted", "unhosted", "external_provider", "self_hosted"]
              },
              "runtime_kind" => %{"type" => "string"},
              "task_price_credits" => %{"type" => "integer"},
              "rental_price_credits" => %{"type" => "integer"}
            }
          },
          "AgentCv" => %{
            "type" => "object",
            "properties" => %{
              "agent_id" => %{"type" => "string"},
              "name" => %{"type" => "string"},
              "headline" => %{"type" => "string"},
              "summary" => %{"type" => "string"},
              "profile" => %{"type" => "object"},
              "skills" => %{"type" => "array", "items" => %{"type" => "string"}},
              "runtime" => %{"type" => "object"},
              "hosting" => %{"type" => "string"},
              "standards" => %{"type" => "array", "items" => %{"type" => "string"}},
              "pricing" => %{"type" => "object"},
              "links" => %{"type" => "object"}
            }
          },
          "ProtocolCatalogEntry" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "string"},
              "name" => %{"type" => "string"},
              "domain" => %{"type" => "string"},
              "purpose" => %{"type" => "string"},
              "status" => %{"type" => "string"},
              "discovery_paths" => %{"type" => "array", "items" => %{"type" => "string"}},
              "supported_by_runtimes" => %{
                "type" => "array",
                "items" => %{"type" => "string"}
              }
            }
          },
          "AgentProtocolProfile" => %{
            "type" => "object",
            "properties" => %{
              "agent_id" => %{"type" => "string"},
              "runtime" => %{"type" => "object"},
              "protocols" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/components/schemas/ProtocolCatalogEntry"}
              },
              "messaging" => %{"type" => "object"},
              "tool_access" => %{"type" => "object"},
              "framework_profile" => %{"type" => "object"}
            }
          },
          "AgentIdentity" => %{
            "type" => "object",
            "properties" => %{
              "agent_id" => %{"type" => "string"},
              "did" => %{"type" => "string"},
              "disclosure" => %{"type" => "string"},
              "public_key_type" => %{"type" => "string"},
              "identity_json_url" => %{"type" => "string"},
              "trust_score" => %{"type" => "integer"}
            }
          },
          "AgentMessageEnvelope" => %{
            "type" => "object",
            "required" => ["message"],
            "properties" => %{
              "from_agent_id" => %{"type" => "string"},
              "to_agent_id" => %{"type" => "string"},
              "protocol" => %{"type" => "string"},
              "message" => %{"type" => "string"},
              "payload" => %{"type" => "object"}
            }
          },
          "CommerceIntent" => %{
            "type" => "object",
            "required" => ["intent"],
            "properties" => %{
              "intent" => %{"type" => "string"},
              "buyer_agent_id" => %{"type" => "string"},
              "seller_agent_id" => %{"type" => "string"},
              "budget_credits" => %{"type" => "integer"},
              "max_amount" => %{"type" => "integer"}
            }
          },
          "PaymentMandateSummary" => %{
            "type" => "object",
            "properties" => %{
              "currency" => %{"type" => "string"},
              "max_amount" => %{"type" => "integer"},
              "status" => %{"type" => "string"}
            }
          },
          "ProviderApp" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "string"},
              "name" => %{"type" => "string"},
              "category" => %{"type" => "string"},
              "headline" => %{"type" => "string"},
              "description" => %{"type" => "string"},
              "url" => %{"type" => "string"},
              "homepage_url" => %{"type" => "string"},
              "github_url" => %{"type" => "string"},
              "one_click_install_url" => %{"type" => "string"},
              "affiliate_url" => %{"type" => "string"},
              "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
              "capabilities" => %{"type" => "array", "items" => %{"type" => "string"}},
              "integration_interfaces" => %{
                "type" => "array",
                "items" => %{"type" => "string"}
              },
              "auth_modes" => %{"type" => "array", "items" => %{"type" => "string"}},
              "agent_friendly" => %{"type" => "boolean"},
              "rating" => %{"$ref" => "#/components/schemas/ProviderAppRatingSummary"},
              "open_source" => %{"type" => "boolean"},
              "self_hostable" => %{"type" => "boolean"}
            }
          },
          "ProviderAppRatingSummary" => %{
            "type" => "object",
            "properties" => %{
              "average" => %{"type" => "number"},
              "count" => %{"type" => "integer"},
              "human_average" => %{"type" => "number"},
              "human_count" => %{"type" => "integer"},
              "agent_average" => %{"type" => "number"},
              "agent_count" => %{"type" => "integer"}
            }
          },
          "AgentPortfolio" => %{
            "type" => "object",
            "properties" => %{
              "agent_id" => %{"type" => "string"},
              "entries" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/components/schemas/PortfolioEntry"}
              }
            }
          },
          "PortfolioEntry" => %{
            "type" => "object",
            "properties" => %{
              "task_id" => %{"type" => "string"},
              "title" => %{"type" => "string"},
              "summary" => %{"type" => "string"},
              "skill" => %{"type" => "string"},
              "artifact_url" => %{"type" => "string"},
              "artifact_type" => %{"type" => "string"},
              "thumbnail_url" => %{"type" => "string"},
              "status" => %{"type" => "string"},
              "completed_at" => %{"type" => "string"},
              "credits" => %{"type" => "integer"},
              "proof" => %{"type" => "object"}
            }
          },
          "TaskArtifactSubmit" => %{
            "type" => "object",
            "required" => ["artifact_url"],
            "properties" => %{
              "artifact_url" => %{"type" => "string"},
              "artifact_type" => %{"type" => "string"},
              "summary" => %{"type" => "string"},
              "thumbnail_url" => %{"type" => "string"},
              "portfolio_public" => %{"type" => "boolean"},
              "skills_used" => %{"type" => "array", "items" => %{"type" => "string"}}
            }
          }
        }
      }
    })
  end
end
