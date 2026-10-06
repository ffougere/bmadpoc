# Decisions et Hypotheses - POC Virtuel

## Hypothese principale (validee)
- Le systeme source reste AIX.
- Le systeme destination reste SAP.
- La migration porte sur le mecanisme de transfert/orchestration/controle.

## Cible technique (a confirmer selon flux)
- Pattern A: EventBridge + Lambda + SQS + Step Functions
- Pattern B: AWS Batch/ECS Fargate + Step Functions + S3
- Pattern C: Hybride (coexistence temporaire legacy + AWS)

## Exigences transverses
- Securite by design: IAM least privilege, Secrets Manager/SSM, KMS, TLS.
- Observabilite: logs, metriques, alertes, correlation des executions.
- Resilience: retry, DLQ, idempotence, procedure de reprise.
- Traçabilite: runbooks, PR, decisions, preuves de tests.

## Gouvernance projet
- Cadre Hub & Spoke pour industrialisation.
- CAP (1-3 jours) pour cadrage et baseline KPI.
- Mission pilote (8-12 semaines) avec incrementation reelle.
- Decision de fin pilote: etendre, ajuster, arreter.

## Industrialisation 60 applications
- Qualification par scoring et questionnaire standard.
- Classement en vagues A/B/C.
- Reutilisation des patterns valides uniquement.

## Points a finaliser
- Choix definitif du pattern par flux.
- Seuils SLA/SLO et KPIs d'acceptation.
- Budget cible et bornes couts finales par classe.
