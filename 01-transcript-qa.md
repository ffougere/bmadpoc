# Transcript Q/R - Projet POC Virtuel

## Entree 01
### Question
Generer une liste complete des services avec resume, cas d'usage et types de tiers au format tableau.

### Reponse
Production d'un tableau de services (AWS natifs + outils tiers), avec resume, cas d'usage et type de tier.

---

## Entree 02
### Question
Donner la liste des contraintes pour migrer une application batch/script AIX vers SAP (cadre CAP, Hub & Spoke, pilote, industrialisation).

### Reponse
Fourniture d'une liste de contraintes structuree : gouvernance, acces, technique, integration SAP, securite, qualite, exploitation, industrialisation, KPI et go/no-go.

---

## Entree 03
### Question
Mettre a jour l'hypothese POC : source et destination inchangees, migration du mecanisme de transfert vers AWS (Lambda/Batch/Serverless) avec securite/authentification. Puis generer grille d'evaluation complete avec hypotheses de charge/couts et questionnaire type pour 60 applications.

### Reponse
Mise a jour du contenu POC avec:
- Hypothese cible AWS (sans changer AIX/SAP)
- Grille d'evaluation et scoring
- Hypotheses de charge L1/L2/L3
- Fourchettes de couts
- Questionnaire type de qualification pour industrialisation

---

## Entree 04
### Question
Confirmer la generation de livrables exploitables.

### Reponse
Generation des fichiers:
- 02-synthese-executive-comite.md
- 03-grille-scoring-industrialisation.csv
- 04-questionnaire-qualification-60-applications.csv

---

## Entree 05
### Question
Donner des exemples de scripts qui transferent des donnees depuis AIX vers SAP SaaS.

### Reponse
Proposition de scripts ksh:
- API SAP SaaS avec OAuth2
- SFTP vers endpoint gere
- JSON API avec retry + controle integrite
- Exemple cron

---

## Entree 06
### Question
Quelles questions poser pour migrer ce type de scripts via services natifs AWS, avec repository/pipeline CI/CD, tests de copie, et mock test sur Kubernetes sans acces AIX/SAP.

### Reponse
Fourniture d'un cadre complet:
- Questions de cadrage migration
- Questions CI/CD
- Questions de tests d'equivalence
- Proposition d'architecture cible AWS
- Plan de mock tests Kubernetes et criteres d'acceptation

---

## Entree 07
### Question
Generer un dossier complet pour conserver les questions/reponses du chat dans des fichiers pour organiser le projet POC virtuel.

### Reponse
Creation du present dossier chat-dossier avec structure, transcript, decisions, livrables et backlog.
