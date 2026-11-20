# OutGold Vagas 5D — acesso independente

Este diretório contém a versão pública inicial em HTML, sem coleta de currículos ou pagamentos.

## Preservação dos dados
- O Google Apps Script OutGold Vagas V4 continua intocado.
- A planilha, a pasta privada de currículos e as implantações existentes não são modificadas.
- Não compartilhe a planilha nem a pasta de currículos como pública.
- Esta versão NÃO é um sistema completo de produção: é um endereço independente e uma prévia segura.

## Publicação
- Hospedar o diretório `outgold-vagas-public` como site estático gratuito no Render.
- Interface acessível por Safari, Chrome e navegador de desktop.
- Não hospedar currículos no site estático e não armazenar senhas no navegador.

## Próximas etapas antes de ativar cadastros e vendas
1. Escolher e conectar uma base de dados persistente com controle por usuário e regras de acesso (ex.: Supabase Free dentro das cotas). Não usar disco local de web service Render Free para dados permanentes.
2. Recriar a autenticação e confirmação por e-mail no novo serviço, sem migrar senhas antigas em texto claro.
3. Migrar empresas e vagas somente após backup e consentimento apropriado; para contas anteriores, enviar fluxo de redefinição de senha.
4. Currículos precisam de armazenamento privado com autorizações por empresa/vaga e política de retenção.
5. Implementar regras de teste gratuito de 7 dias no SERVIDOR; um teste por empresa, sujeito a auditoria.
6. Implementar planos de 30/365 dias e aprovação manual Pix após conferência bancária.
7. Testar com contas separadas: candidato, empresa, administrador; verificar RLS e privacidade; executar testes em iOS e Android reais.
8. Após o teste real e avaliação jurídica/LGPD, liberar coleta de currículos e pagamento e retirar o aviso de prévia.

## Planos propostos
- Essencial: R$ 19,90 / 30 dias ou R$ 199 / 365 dias — 1 vaga ativa.
- Profissional: R$ 39,90 / 30 dias ou R$ 399 / 365 dias — 5 vagas.
- Destaque: R$ 79,90 / 30 dias ou R$ 799 / 365 dias — 20 vagas.

## Limitações
Site estático não consegue executar `google.script.run` fora da página hospedada pelo Google Apps Script. Apontar apenas o HTML antigo para o Render quebraria cadastro, autenticação e currículos. Por isso esta versão utiliza uma prévia segura em vez de simular transações reais.

O logotipo utilizado é referenciado sem alterações a partir do repositório original OutGold.

© Tecnologia OutGold — projeto do titular da conta.
