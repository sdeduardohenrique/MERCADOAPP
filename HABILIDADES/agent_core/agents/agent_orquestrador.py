"""
Agente Orquestrador do MERCADO APP
====================================

Este módulo inicializa e registra todas as ferramentas instaladas dos 8 repositórios
como funções invocáveis pelo modelo. Serve como o núcleo de coordenação do sistema.
"""

import os
import sys
import json
import asyncio
from pathlib import Path
from typing import Dict, List, Any, Optional, Callable

# Adicionar o diretório do agent_core ao path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Coleção de ferramentas registradas
registered_tools: Dict[str, Callable] = {}

def register_tool(name: str, func: Callable) -> None:
    """Registra uma ferramenta como função invocável pelo modelo."""
    registered_tools[name] = func
    print(f"✓ Ferramenta registrada: {name}")

def get_registered_tools() -> Dict[str, Callable]:
    """Retorna dicionário de todas as ferramentas registradas."""
    return dict(registered_tools)

# ============================================================
# TOOLS FROM CHROME DEVTOOLS MCP
# ============================================================
try:
    from chrome_devtools_mcp import ChromeDevToolsClient
    def list_chrome_tabs() -> Dict[str, Any]:
        """Lista abas abertas no Chrome via DevTools MCP."""
        client = ChromeDevToolsClient()
        return asyncio.run(client.list_tabs())
    register_tool("list_chrome_tabs", list_chrome_tabs)
except ImportError as e:
    print(f"⚠ Aviso: chrome-devtools-mcp não disponível: {e}")

try:
    from chrome_devtools_mcp import NetworkMonitor
    def capture_network_traffic() -> Dict[str, Any]:
        """Capture tráfego de rede do Chrome."""
        monitor = NetworkMonitor()
        return asyncio.run(monitor.capture())
    register_tool("capture_network_traffic", capture_network_traffic)
except ImportError as e:
    print(f"⚠ Aviso: chrome-devtools-mcp network monitor não disponível: {e}")

# ============================================================
# TOOLS FROM GLYPH
# ============================================================
try:
    from glyph import GlyphProcessor
    def process_glyph_image(image_path: str) -> Dict[str, Any]:
        """Processa imagem usando Glyph AI."""
        processor = GlyphProcessor()
        return processor.analyze(image_path)
    register_tool("process_glyph_image", process_glyph_image)
except ImportError as e:
    print(f"⚠ Aviso: Glyph não disponível: {e}")

# ============================================================
# TOOLS FROM FIRECRAWL
# ============================================================
try:
    from firecrawl import FirecrawlClient
    def scrape_website(url: str) -> Dict[str, Any]:
        """Faz scrape de um website usando Firecrawl."""
        client = FirecrawlClient()
        return asyncio.run(client.scrape(url))
    register_tool("scrape_website", scrape_website)
except ImportError as e:
    print(f"⚠ Aviso: firecrawl cliente não disponível: {e}")

# ============================================================
# TOOLS FROM PLAYWRIGHT
# ============================================================
try:
    from playwright.async_api import async_playwright
    def browser_search(query: str, headless: bool = True) -> Dict[str, Any]:
        """Busca no navegador usando Playwright."""
        async def _search():
            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=headless)
                page = await browser.new_page()
                await page.goto(f"https://duckduckgo.com/?q={query}")
                await page.wait_for_selector('#result')
                results = await page.eval_on_selector_all('#result .result', 'els => els.map(e => e.innerText)')
                await browser.close()
                return {"query": query, "results": results[:10]}
        return asyncio.run(_search())
    register_tool("browser_search", browser_search)
except ImportError as e:
    print(f"⚠ Aviso: Playwright browser search não disponível: {e}")

# ============================================================
# TOOLS FROM MODEL CONTEXT PROTOCOL
# ============================================================
try:
    from mcp import MCPClient
    def mcp_query(query: str) -> Dict[str, Any]:
        """Query via Model Context Protocol."""
        client = MCPClient()
        return asyncio.run(client.query(query))
    register_tool("mcp_query", mcp_query)
except ImportError as e:
    print(f"⚠ Aviso: Model Context Protocol não disponível: {e}")

# ============================================================
# TOOLS FROM GRAPHIFY
# ============================================================
try:
    from graphify import GraphifyEngine
    def analyze_graph(data: Dict[str, Any]) -> Dict[str, Any]:
        """Analisa dados usando motor Graphify."""
        engine = GraphifyEngine()
        return engine.process(data)
    register_tool("analyze_graph", analyze_graph)
except ImportError as e:
    print(f"⚠ Aviso: Graphify não disponível: {e}")

# ============================================================
# TOOLS FROM AGENT SKILLS
# ============================================================
try:
    from agent_skills.core import SkillRegistry
    def list_available_skills() -> Dict[str, Any]:
        """Lista skills disponíveis do agente-skills."""
        registry = SkillRegistry()
        return registry.list_skills()
    register_tool("list_available_skills", list_available_skills)
except ImportError as e:
    print(f"⚠ Aviso: agent-skills core não disponível: {e}")

# ============================================================
# TOOLS FROM STRIX
# ============================================================
try:
    from strix import StrixClient
    def strix_analyze(text: str) -> Dict[str, Any]:
        """Analisa texto usando Strix."""
        client = StrixClient()
        return asyncio.run(client.analyze(text))
    register_tool("strix_analyze", strix_analyze)
except ImportError as e:
    print(f"⚠ Aviso: Strix não disponível: {e}")

# ============================================================
# ORCHESTRATOR CORE
# ============================================================

class Orchestrator:
    """Orquestrador principal que gerencia e invoca todas as ferramentas."""

    def __init__(self):
        self.tools = get_registered_tools()
        self.initialized = False

    async def initialize(self) -> None:
        """Inicializa todas as ferramentas dependendo se são assíncronas ou síncronas."""
        if self.initialized:
            return
        # Verificar e inicializar ferramentas que precisam de setup
        for name, func in self.tools.items():
            try:
                # Teste rápido de conexão/initialização
                if callable(func):
                    func()  # Chamada simples para verificar disponibilidade
            except Exception as e:
                print(f"⚠ Ferramenta {name} requer atenção: {e}")
        self.initialized = True
        print("✓ Orquestrador inicializado com sucesso")

    def execute(self, tool_name: str, **kwargs) -> Any:
        """Executa uma ferramenta registrada pelo nome."""
        if tool_name not in self.tools:
            raise ValueError(f"Ferramenta '{tool_name}' não encontrada. Disponíveis: {list(self.tools.keys())}")
        func = self.tools[tool_name]
        try:
            return func(**kwargs)
        except Exception as e:
            print(f"✗ Erro ao executar {tool_name}: {e}")
            return {"error": str(e), "tool": tool_name}

    def list_tools(self) -> List[str]:
        """Retorna lista de nomes de ferramentas disponíveis."""
        return list(self.tools.keys())

# Instância global do orquestrador
orchestrator = Orchestrator()

def init_orchestrator() -> Orchestrator:
    """Função de inicialização para ser chamada no startup do sistema."""
    asyncio.get_event_loop().run_until_complete(orchestrator.initialize())
    return orchestrator

def run_tool(tool_name: str, **kwargs) -> Any:
    """Função de conveniência para executar uma ferramenta."""
    return orchestrator.execute(tool_name, **kwargs)

# ============================================================
# PROMPTS E CONFIGURATION
# ============================================================

def load_prompt(prompt_name: str) -> Optional[str]:
    """Carrega um prompt do diretório de prompts."""
    prompt_path = Path(__file__).parent.parent / "prompts" / f"{prompt_name}.txt"
    if prompt_path.exists():
        return prompt_path.read_text(encoding="utf-8")
    return None

def load_config(config_name: str) -> Optional[Dict[str, Any]]:
    """Carrega configuração do diretório de config."""
    config_path = Path(__file__).parent.parent / "config" / f"{config_name}.json"
    if config_path.exists():
        return json.loads(config_path.read_text(encoding="utf-8"))
    return None

# ============================================================
# EXEMPLO DE USO
# ============================================================

if __name__ == "__main__":
    print("=== MERCADO APP - Agente Orquestrador ===\n")
    
    # Inicializar orquestrador
    orch = init_orchestrator()
    
    # Listar ferramentas disponíveis
    print("Ferramentas disponíveis:")
    for tool_name in orch.list_tools():
        print(f"  - {tool_name}")
    
    # Exemplo de execução (comentado para evitar chamadas reais)
    # result = run_tool("scrape_website", url="https://example.com")
    # print(f"\nResultado: {json.dumps(result, indent=2, default=str)}")