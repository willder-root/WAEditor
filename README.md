# WAEditor

Editor de texto **WYSIWYG** com suporte a **HTML** e **RTF** para Delphi 10.2 Tokyo, construído em **Clean Architecture** com cobertura de testes unitários (DUnitX).

O editor usa um `TWebBrowser` em modo `designMode="On"` (contentEditable) como superfície de edição — ou seja, o usuário formata o texto visualmente (negrito, fonte, tabela, alinhamento) e vê o resultado renderizado em tempo real, sem editar markup bruto.

## Funcionalidades

- **Fonte**: tipo (família) e tamanho.
- **Parágrafo**: alinhamento (esquerda, centro, direita, justificado).
- **Estilo de caractere**: negrito, itálico, sublinhado.
- **Tabela**: inserção com linhas, colunas e largura de borda configuráveis.
- **Listas**: não ordenada (marcadores) e ordenada (numerada).
- **Documento HTML**: novo, abrir e salvar (`.html`).
- **Documento RTF**: abrir e salvar (`.rtf`), com conversão bidirecional HTML WYSIWYG ⇄ RTF preservando toda a formatação acima (ver [Conversão HTML ⇄ RTF](#conversão-html--rtf)).

## Arquitetura

O projeto segue Clean Architecture: as regras de negócio (`Domain`/`Application`) não dependem de VCL, COM ou de nenhuma biblioteca de UI. Apenas a borda externa (`Infrastructure`/`Presentation`) conhece o `TWebBrowser` e o sistema de arquivos.

```
src/
├── Domain/          Modelos e regras puras — sem dependência de VCL/COM
├── Application/     Casos de uso e contratos (interfaces) implementados pela Infrastructure
│   ├── Interfaces/
│   ├── Commands/
│   └── Services/
├── Infrastructure/  Adaptadores concretos (TWebBrowser, sistema de arquivos)
│   ├── WebBrowser/
│   └── FileSystem/
└── Presentation/    Formulários VCL (toolbar, diálogos)
```

A regra de dependência é sempre em direção ao centro: `Presentation` e `Infrastructure` dependem de `Application`, que depende de `Domain`. Nunca o inverso.

| Camada | Responsabilidade | Depende de |
|---|---|---|
| **Domain** | Value objects (`TWAFontSpec`, `TWATableSpec`), mapeadores puros e o modelo de documento rico (`TWARichDocument`) usado para converter entre HTML e RTF | nada (apenas RTL) |
| **Application** | Casos de uso: comandos de formatação (`TWASetFontSizeCommand`, `TWAInsertTableCommand`, ...) e serviços de documento (`TWADocumentService`, `TWARtfDocumentService`) | Domain |
| **Infrastructure** | `TWAWebBrowserEditorEngine` (adapta `TWebBrowser`/`IHTMLDocument2` a `IWAHtmlEditorEngine`) e `TWAFileHtmlDocumentStorage` (leitura/escrita de arquivo) | Application, Domain |
| **Presentation** | `TWAMainForm` (toolbar + `TWebBrowser`) e `TWAInsertTableDialog` | Application, Domain |

Cada comando de formatação (`IWAEditorCommand`) valida seus próprios parâmetros usando os value objects do Domain antes de chamar o motor de edição (`IWAHtmlEditorEngine`), que é uma interface — permitindo substituir o `TWebBrowser` real por um fake nos testes.

### Conversão HTML ⇄ RTF

Para abrir/salvar `.rtf`, o editor não depende de nenhum controle de RTF do Windows: os conversores foram escritos do zero na camada `Domain`, usando `TWARichDocument` como modelo intermediário neutro:

```
HTML (WYSIWYG) → TWAHtmlDocumentParser  → TWARichDocument → TWARtfDocumentRenderer → RTF
RTF             → TWARtfDocumentParser  → TWARichDocument → TWAHtmlDocumentRenderer → HTML (WYSIWYG)
```

> **Limitação conhecida**: os parsers cobrem o subconjunto de HTML/RTF que o próprio editor produz e consome (parágrafos, tabelas, negrito/itálico/sublinhado, fonte e tamanho, alinhamento) — não são parsers genéricos para HTML/RTF arbitrário vindo de outras ferramentas.

## Estrutura do repositório

```
WAEditor/
├── WAEditor.dpk / .dproj        Pacote Delphi contendo todas as camadas (gera WAEditor.bpl)
├── boss.json                    Manifesto para instalação via Boss
├── src/                         Código-fonte (ver Arquitetura acima)
├── tests/                       Testes unitários DUnitX
│   ├── Domain/
│   ├── Application/
│   ├── Fakes/                   Dublês de teste (TFakeHtmlEditorEngine, TFakeHtmlDocumentStorage)
│   └── WAEditorTests.dpr        Executável de testes (console)
└── demos/
    ├── WAEditorDemo/            Aplicação VCL completa — o editor rodando
    └── WAEditorConsoleDemo/     Console: converte um HTML de exemplo para RTF e imprime o resultado
```

## Requisitos

- Delphi 10.2 Tokyo (ou compatível — os projetos usam `ProjectVersion 18.4`).
- Windows (o motor de edição depende de `TWebBrowser`/MSHTML, componentes Win32).

## Como executar

**Editor completo (VCL):** abra e execute [`demos/WAEditorDemo/WAEditorDemo.dproj`](demos/WAEditorDemo/WAEditorDemo.dproj).

**Conversor HTML → RTF (console):** abra e execute [`demos/WAEditorConsoleDemo/WAEditorConsoleDemo.dproj`](demos/WAEditorConsoleDemo/WAEditorConsoleDemo.dproj) — não precisa de UI, imprime o HTML de entrada e o RTF gerado no terminal.

**Pacote reutilizável:** abra [`WAEditor.dproj`](WAEditor.dproj) para compilar `WAEditor.bpl`, contendo todas as units do editor prontas para serem usadas em outro projeto.

## Testes

Os testes usam [DUnitX](https://github.com/VSoftTechnologies/DUnitX) e cobrem Domain e Application (comandos, serviços de documento, renderizadores/parsers de HTML e RTF, incluindo testes de *round-trip*: modelo → HTML → modelo, modelo → RTF → modelo).

Abra e execute [`tests/WAEditorTests.dpr`](tests/WAEditorTests.dpr) (aplicação console) para rodar toda a suíte.

A camada `Infrastructure` (adaptador do `TWebBrowser`) não é coberta por testes automatizados por depender de COM/UI — deve ser validada manualmente na IDE.

## Instalação via Boss

Este projeto pode ser instalado como dependência via [Boss](https://github.com/HashLoad/boss):

```bash
boss install github.com/willder-root/WAEditor
```

## Commits

O histórico segue [Conventional Commits](https://www.conventionalcommits.org/) (`feat`, `fix`, `test`, `chore`, ...), com um commit por mudança logicamente coesa.

## Licença

[MIT](LICENSE)
