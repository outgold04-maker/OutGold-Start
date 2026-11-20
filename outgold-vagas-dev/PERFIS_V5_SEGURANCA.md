# OutGold Vagas 5D — Perfis V5: roteiro técnico seguro
Estado: especificação. Não executado em produção.

## Publicado hoje
A interface estática apresenta abas Início, Vagas, Candidato, Empresas, Planos, Informações e aceita foto de candidato e logotipo de empresa. Ao tocar em "Salvar prévia neste aparelho", as imagens são reduzidas para JPEG de 420 x 420 pixels e armazenadas no próprio navegador, junto a nome/área/cidade. Isso NÃO cria conta, não envia arquivos para servidor e não sincroniza aparelhos. A opção "Remover prévia" apaga a cópia local.

## Requisitos técnicos de produção

### Candidato
- Cadastro com login autenticado e confirmação de e-mail.
- Campos: ID, nome de exibição, cidade/UF, área, foto privada opcional, consentimentos, datas.
- Upload JPEG/PNG/WebP, máximo 3 MB, validação do conteúdo de fato no servidor, retirada de EXIF e de metadados pessoais, limite de dimensões e nomes aleatórios gerados no servidor.
- Foto privada por padrão; recrutadores somente veem perfil e arquivos se existir candidatura legítima à vaga de sua empresa.
- Currículos sempre armazenados em bucket privado com URLs de acesso temporárias e auditáveis.

### Empresa
- Cadastro com e-mail confirmado, CNPJ validado, nome, área e localização.
- Logo opcional, arquivo reprocessado no backend, sem aceitar SVG e sem scripts incorporados.
- Apenas proprietário autenticado edita. Divulgar logo somente após moderar/validar a empresa.

### Planos
- Teste grátis 7 dias a partir da ativação no servidor, uma vez por empresa elegível, limite 3 vagas ativas.
- Essencial: 1 vaga, R$19,90 / 30 dias ou R$199 / 365 dias.
- Profissional: 5 vagas, R$39,90 / 30 dias ou R$399 / 365 dias.
- Destaque: 20 vagas, R$79,90 / 30 dias ou R$799 / 365 dias.
- Após expiração, ocultar anúncios. Pix não autoriza automaticamente acesso; conferir crédito no banco e liberar apenas via administrativo autenticado.
- Autorização, bloqueio, cancelamentos e pagamentos têm trilha de auditoria, sem credenciais de administrador no navegador.

### Segurança
- LGPD: transparência, finalidade, bases legais, minimização, retenção, exclusão, contato de privacidade.
- Controle de acesso por usuário/empresa no servidor e testes RLS entre duas empresas e dois candidatos.
- Antiabuso, limitação de taxa, auditoria, tratamento de incidentes, backup restaurável, teste físico em Android e iOS.
- Nenhum dado de candidatura no hosting estático; sem segredos de backend em código público.

## Pendente
Criar/conectar banco persistente (plano gratuito sujeito a limites), autenticação e armazenamento privado. Migrar com backup e controles de segurança. Testar login, upload, candidaturas, recebimento, Pix, aprovação, expiração e moderação. Somente então habilitar cadastros reais no novo endereço. O Apps Script original e sua planilha estão preservados.
