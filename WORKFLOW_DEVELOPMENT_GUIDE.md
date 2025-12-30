# n8n Workflow Development with Claude Code - Complete Guide

## 📚 Table of Contents
1. [Tool Overview](#tool-overview)
2. [Setup Status](#setup-status)
3. [How to Use Each Tool](#how-to-use-each-tool)
4. [Workflow Development Process](#workflow-development-process)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)

---

## 🎯 Tool Overview

You now have **TWO powerful tools** for building n8n workflows with Claude Code:

### **1. n8n-skills** (Primary Development Tool) ✅ **INSTALLED**
**Purpose:** Build workflows from scratch with expert guidance

**What it includes:**
- 7 specialized skills that work together:
  1. **n8n Expression Syntax** - Teaches {{}} syntax, $json/$node variables
  2. **n8n MCP Tools Expert** - How to use MCP tools effectively
  3. **n8n Workflow Patterns** - 5 proven architectural patterns
  4. **n8n Validation Expert** - Fix validation errors and loops
  5. **n8n Node Configuration** - Operation-aware node setup
  6. **n8n Code JavaScript** - Write Code nodes correctly
  7. **n8n Code Python** - Understand Python limitations

**Coverage:**
- 543 n8n nodes (99% coverage)
- 2,646 real-world configuration examples
- 10 production-tested Code node patterns

**Location:** `~/.claude/skills/`

### **2. n8n-mcp** (Runtime & Monitoring Tool) ⚠️ **NEEDS API KEY**
**Purpose:** Interact with your live n8n instance at https://n8n.masadvise.org

**What it provides:**
- Query workflow status and execution history
- Trigger workflow executions
- Debug running workflows
- Access real-time workflow data

**Location:** Configured in `/home/brian/workspace/development` project
**Configuration:** `/home/brian/workspace/docker/development/n8n-mcp-server/.env`

---

## ✅ Setup Status

### **n8n-skills** ✅ READY TO USE
- [x] Repository cloned
- [x] Skills copied to `~/.claude/skills/`
- [x] Auto-activates based on your queries
- [x] No additional configuration needed

**Test it now:**
```
Ask Claude: "How do I access webhook data in an n8n Code node?"
→ Should activate n8n-code-javascript skill
```

### **n8n-mcp** ⚠️ NEEDS API KEY
- [x] Docker image pulled
- [x] MCP server configured in Claude Code
- [x] Environment file created (`.env.example`)
- [ ] **REQUIRED:** Add your n8n API key

**To complete setup:**

1. **Get your n8n API key:**
   - Open https://n8n.masadvise.org
   - Log in (username: `brian`)
   - Go to Settings (gear icon) > API
   - Copy your "Claude AI Assistant" API key (starts with `n8n_api_...`)

2. **Update the .env file:**
   ```bash
   cd /home/brian/workspace/docker/development/n8n-mcp-server
   nano .env
   ```

   Replace `REPLACE_WITH_YOUR_API_KEY` with your actual key:
   ```bash
   N8N_API_KEY=n8n_api_1234567890abcdef  # Your actual key here
   ```

3. **Reload VS Code:**
   - Press `Ctrl+Shift+P`
   - Type "Developer: Reload Window"
   - Press Enter

4. **Verify it works:**
   ```
   Ask Claude: "List all workflows in my n8n instance"
   → Should connect to https://n8n.masadvise.org and list your workflows
   ```

---

## 🚀 How to Use Each Tool

### **Using n8n-skills (Automatic)**

The skills activate **automatically** based on what you ask:

#### **Skill 1: n8n Expression Syntax**
**Activates when:** Writing expressions, using {{}} syntax, accessing $json/$node

**Example queries:**
```
"How do I access webhook data in an n8n expression?"
"What's the difference between $json and $node?"
"How do I reference data from a previous node?"
```

**What you'll learn:**
- Core variables: `$json`, `$node`, `$now`, `$env`
- **Critical gotcha:** Webhook data is under `$json.body`
- When NOT to use expressions (use Code nodes instead)

---

#### **Skill 2: n8n MCP Tools Expert** (HIGHEST PRIORITY)
**Activates when:** Searching for nodes, validating configurations, accessing templates

**Example queries:**
```
"Find me a Slack node for sending messages"
"How do I validate this workflow configuration?"
"Show me HTTP Request node operations"
```

**What you'll learn:**
- Correct tool usage patterns (search_nodes → get_node_essentials)
- nodeType format differences (nodes-base.* vs n8n-nodes-base.*)
- Validation profiles (minimal/runtime/strict)
- Smart parameters (branch="true" for IF nodes)

---

#### **Skill 3: n8n Workflow Patterns**
**Activates when:** Creating workflows, connecting nodes, designing automation

**Example queries:**
```
"Build a webhook to Slack workflow"
"How do I process incoming HTTP requests?"
"Create a scheduled data pipeline"
```

**5 Proven Patterns:**
1. **Webhook Processing** - Handle incoming webhooks
2. **HTTP API** - Make external API calls
3. **Database Operations** - Query and update databases
4. **AI Workflows** - Integrate AI models
5. **Scheduled Tasks** - Run workflows on a schedule

---

#### **Skill 4: n8n Validation Expert**
**Activates when:** Validation fails, debugging workflow errors

**Example queries:**
```
"Why is validation failing for my workflow?"
"How do I fix this validation loop?"
"Are there false positives I should ignore?"
```

**What you'll learn:**
- Validation loop workflow
- Real error catalog with solutions
- Auto-sanitization behavior
- Profile selection for different stages

---

#### **Skill 5: n8n Node Configuration**
**Activates when:** Configuring nodes, understanding property dependencies

**Example queries:**
```
"How do I configure the HTTP Request node?"
"What properties are required for the Slack node?"
"How do I set up AI Agent connections?"
```

**What you'll learn:**
- Property dependency rules (e.g., sendBody → contentType)
- Operation-specific requirements
- AI connection types (8 types for AI Agent workflows)

---

#### **Skill 6: n8n Code JavaScript**
**Activates when:** Writing JavaScript in Code nodes

**Example queries:**
```
"How do I access webhook data in a Code node?"
"What's the correct return format for Code nodes?"
"How do I make HTTP requests with $helpers?"
```

**Key Features:**
- Data access patterns ($input.all(), $input.first(), $input.item)
- **Critical gotcha:** Webhook data under `$json.body`
- Correct return format: `[{json: {...}}]`
- Built-in functions ($helpers.httpRequest(), DateTime, $jmespath())
- Top 5 error patterns with solutions

---

#### **Skill 7: n8n Code Python**
**Activates when:** Writing Python in Code nodes, need to know limitations

**Example queries:**
```
"Can I use pandas in Python Code node?"
"How do I access data in Python Code nodes?"
"What Python libraries are available?"
```

**Important:**
- **Use JavaScript for 95% of use cases** (Python has limitations)
- **Critical limitation:** No external libraries (no requests, pandas, numpy)
- Standard library available (json, datetime, re, etc.)
- Workarounds for missing libraries

---

### **Using n8n-mcp (Manual - After Setup)**

Once you add your API key, you can query your live n8n instance:

#### **List Workflows**
```
Ask Claude: "List all workflows in my n8n instance"
```

#### **Get Workflow Details**
```
Ask Claude: "Show me details for the 'Contact Sync' workflow"
```

#### **Check Execution Status**
```
Ask Claude: "Why did my email workflow fail last night?"
```

#### **Trigger Workflow**
```
Ask Claude: "Trigger the 'Daily Report' workflow"
```

---

## 🔄 Workflow Development Process

### **Approach 1: Start from Scratch (Use n8n-skills)**

**Step 1: Describe your goal**
```
You: "I need a workflow that sends daily email reports from Google Sheets"
```

**Step 2: Claude uses n8n-skills to:**
1. **n8n Workflow Patterns** identifies "Scheduled Tasks" pattern
2. **n8n MCP Tools Expert** searches for Schedule, Google Sheets, Email nodes
3. **n8n Node Configuration** guides node setup
4. **n8n Expression Syntax** helps with data mapping
5. **n8n Code JavaScript** processes data if needed
6. **n8n Validation Expert** validates the final workflow

**Step 3: Claude generates complete workflow JSON**

**Step 4: Import to n8n**
- Copy the workflow JSON
- Open https://n8n.masadvise.org
- Click "Import from File" or paste JSON directly
- Test and activate

---

### **Approach 2: Debug Existing Workflow (Use n8n-mcp + n8n-skills)**

**Step 1: Check workflow status**
```
You: "Why is my 'Contact Sync' workflow failing?"

Claude (using n8n-mcp):
- Connects to https://n8n.masadvise.org
- Retrieves execution history
- Analyzes error logs
```

**Step 2: Claude identifies the issue**
```
Claude (using n8n-skills):
- n8n Validation Expert interprets the error
- n8n Node Configuration suggests fixes
- n8n Code JavaScript rewrites Code node if needed
```

**Step 3: Apply the fix**
- Claude updates the workflow JSON
- You import the fixed workflow
- Test again

---

### **Approach 3: Learn n8n Concepts**

**Example 1: Understanding Expressions**
```
You: "How do I access webhook data in n8n?"

Claude (activates n8n Expression Syntax skill):
- Explains $json.body for webhooks
- Shows examples from 2,646 templates
- Warns about common mistakes
```

**Example 2: Best Practices**
```
You: "What's the best way to handle errors in n8n?"

Claude (activates n8n Workflow Patterns skill):
- Shows error handling pattern
- Demonstrates Error Trigger node
- Provides real-world example
```

---

## 📋 Best Practices (from 2025 Research)

### **1. Structured Development Workflow**
Follow: **Research → Plan → Implement**
- Never jump straight to coding
- Use n8n-skills to research nodes first
- Plan the workflow structure
- Then implement with validation

### **2. Progressive Validation Approach**
Use three-tier validation strategy:
1. **"ai-friendly" profile** - Fast development
2. **"runtime" profile** - Medium validation
3. **"strict" profile** - Production-ready

### **3. Core Configuration Principles**
- Every node references upstream data using `$node["NodeName"]` syntax
- Pass relevant context along
- Handle errors with dedicated error workflows

### **4. Error Handling & Monitoring**
- Configure dedicated error workflows using Error Trigger node
- Log error details when Claude API calls fail
- Send notifications to Slack/email

### **5. Cost Optimization**
- Design workflows with dynamic model selection
- Use cost-effective models for each task
- Carefully engineer prompts (you pay for input + output tokens)

### **6. Rate Limit Management**
- Use n8n's Wait node to add delays in loops
- Build retry logic for 429 errors

---

## ⚡ Quick Reference

### **Common Workflow Triggers**
- **Chat Trigger** - Conversational agents
- **Webhook Trigger** - External API calls
- **Schedule Trigger** - Periodic tasks

### **Most Used n8n Nodes (from 31,917 workflows)**
1. **HTTP Request** - Make API calls
2. **Code** - Custom JavaScript/Python logic
3. **IF** - Conditional branching
4. **Aggregate** - Combine data from multiple sources
5. **Set** - Transform data structure
6. **Gmail** - Send/receive emails
7. **Google Sheets** - Read/write spreadsheets
8. **Slack** - Send messages
9. **OpenAI** - AI model integration
10. **Webhook** - Receive HTTP requests

### **Critical Gotchas to Remember**
1. **Webhook data is under `$json.body`** (not `$json`)
2. **Code node return format:** `[{json: {...}}]` (array of objects)
3. **Python Code nodes:** No external libraries (use JavaScript instead)
4. **Expression syntax:** Use `{{$node["NodeName"].json.field}}`, not `{{$json.field}}`
5. **nodeType format:** Sometimes `nodes-base.slack`, sometimes `n8n-nodes-base.slack`

---

## 🛠 Troubleshooting

### **Issue: n8n-skills not activating**

**Symptoms:** Claude doesn't use skills when you ask workflow questions

**Solutions:**
1. Check skills are installed:
   ```bash
   ls ~/.claude/skills/
   # Should show: n8n-expression-syntax, n8n-mcp-tools-expert, etc.
   ```

2. Reload VS Code:
   - Press `Ctrl+Shift+P`
   - Type "Developer: Reload Window"
   - Press Enter

3. Try a more specific query:
   ```
   Instead of: "Help with n8n"
   Try: "How do I access webhook data in an n8n Code node?"
   ```

---

### **Issue: n8n-mcp not connecting**

**Symptoms:** Claude says "I cannot connect to your n8n instance"

**Solutions:**
1. **Check API key is set:**
   ```bash
   cat /home/brian/workspace/docker/development/n8n-mcp-server/.env | grep N8N_API_KEY
   # Should show: N8N_API_KEY=n8n_api_...
   ```

2. **Test n8n is accessible:**
   ```bash
   curl -I https://n8n.masadvise.org
   # Should return: HTTP/2 200
   ```

3. **Verify MCP server is configured:**
   ```bash
   cat ~/.claude.json | grep -A 10 '"n8n-mcp"'
   # Should show Docker command configuration
   ```

4. **Check Azure Container App status:**
   ```bash
   az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg --query "properties.runningStatus"
   # Should return: "Running"
   ```

---

### **Issue: Claude generates invalid workflow JSON**

**Symptoms:** n8n says "Invalid workflow" when importing

**Solutions:**
1. **Ask Claude to validate:**
   ```
   "Please validate this workflow using the strict profile"
   ```

2. **Check node connections:**
   ```
   "Are all nodes properly connected with valid references?"
   ```

3. **Use validation expert:**
   ```
   "Why is this workflow failing validation?"
   ```

---

## 📖 Additional Resources

### **Official Documentation**
- **n8n Documentation:** https://docs.n8n.io/
- **n8n-skills README:** `/home/brian/workspace/docker/development/n8n-skills/README.md`
- **n8n-mcp README:** `/home/brian/workspace/docker/development/n8n-mcp-server/README.md`
- **n8n Azure Deployment:** `CLAUDE.md` (this directory)

### **Community Resources**
- **n8n-skills GitHub:** https://github.com/czlonkowski/n8n-skills
- **n8n-mcp GitHub:** https://github.com/czlonkowski/n8n-mcp
- **n8n Community:** https://community.n8n.io/
- **n8n Templates:** https://n8n.io/workflows/ (2,646+ examples)

### **Your Workflow Repositories**
- **Allard Prize Workflows:** `/home/brian/workspace/docker/development/n8n-ap-workflows/`
- **Personal Workflows:** `/home/brian/workspace/docker/development/n8n-brian-workflows/`

---

## 🎉 You're All Set!

**What you have now:**
1. ✅ **n8n-skills** - 7 expert skills for workflow development
2. ⚠️ **n8n-mcp** - Runtime monitoring (add API key to activate)
3. ✅ **543 n8n nodes** documented
4. ✅ **2,646 workflow examples** available
5. ✅ **10 production-tested patterns**

**Next steps:**
1. **Complete n8n-mcp setup** (add API key)
2. **Test n8n-skills:** Ask Claude a workflow question
3. **Build your first workflow:** Start with a simple pattern
4. **Iterate and improve:** Use validation and debugging tools

**Need help?** Just ask Claude:
- "How do I...?" → n8n-skills will guide you
- "Why is this failing?" → n8n-mcp + n8n-skills will debug
- "Show me an example of..." → 2,646 templates available

---

**Created:** December 29, 2025
**For:** Brian Flett (brian.flett@masadvise.org)
**Instance:** https://n8n.masadvise.org (Azure Container Apps)
