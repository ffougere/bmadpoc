# Actions et Livrables - POC Virtuel

## Livrables existants

| Livrable | Chemin | Statut | Usage |
|---|---|---|---|
| Input de cadrage POC | ../01-input.md | A verifier (historique mixte) | Base de contexte |
| Synthese executive comite | ../02-synthese-executive-comite.md | Pret | Support decisionnel |
| Grille scoring industrialisation | ../03-grille-scoring-industrialisation.csv | Pret | Qualification A/B/C |
| Questionnaire 60 apps | ../04-questionnaire-qualification-60-applications.csv | Pret | Collecte topologie/SLA/dependances |
| Dossier chat | ./ | Pret | Capitalisation knowledge |

## Actions recommandees (prochain sprint)

| Action | Responsable propose | Priorite | Echeance | Critere de done |
|---|---|---|---|---|
| Nettoyer 01-input.md pour version finale unique | PMO/Architecte | Haute | Semaine 1 | Document coherent sans doublons |
| Renseigner 10 applications pilotes dans la grille | Equipes produit | Haute | Semaine 1-2 | 10 lignes completees |
| Executer ateliers questionnaire (60 apps) | BNC + CGI | Haute | Semaine 2-4 | 60 fiches qualifiees |
| Definir seuils go/no-go SLA/SLO | Ops + Securite + Metier | Haute | Semaine 2 | Seuils signes |
| Definir pipeline CI/CD standard migration | DevOps | Moyenne | Semaine 3 | Pipeline template valide |
| Monter banc de tests mock Kubernetes | QA + DevOps | Moyenne | Semaine 3-4 | Campagnes de tests executables |

## KPI de suivi execution
- Taux de qualification des applications
- Nombre de patterns reutilisables valides
- Taux de succes tests d'equivalence
- Respect fenetre batch cible
- MTTR sur incidents simules
