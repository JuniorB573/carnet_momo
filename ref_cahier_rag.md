# Cahier des charges — Assistant RAG « Lois numériques du Bénin »

| | |
|---|---|
| **Projet** | Assistant conversationnel d'information sur le droit du numérique au Bénin, fondé sur la recherche dans les textes officiels (RAG) |
| **Porteur** | *à compléter* |
| **Version / date** | v1.1 — 9 octobre 2026 |

## 1. Contexte

Les textes qui encadrent le numérique au Bénin (Code du numérique, Code pénal) sont longs, techniques et difficiles d'accès pour le citoyen ordinaire. Or les situations rencontrées en ligne (photo publiée sans accord, diffamation, piratage de compte, usage des données personnelles) soulèvent des questions juridiques concrètes.

Un modèle de langage utilisé seul peut inventer des articles ou des sanctions, ce qui est inacceptable en matière de droit. Le projet propose donc une approche **RAG** (génération augmentée par recherche) : le système retrouve d'abord les articles pertinents, puis rédige une réponse uniquement à partir d'eux.

## 2. Objectifs

**Objectif général** : permettre à toute personne de poser une question en langage courant et d'obtenir une réponse claire, fondée uniquement sur les textes officiels, avec la référence exacte de l'article.

**Objectifs spécifiques**
- Rendre le droit du numérique béninois accessible sans formation juridique.
- Garantir la traçabilité : chaque réponse renvoie à la loi et à l'article d'origine.
- Éviter les « hallucinations » : le système refuse de répondre quand les textes ne couvrent pas la question.
- Fournir une application web simple, utilisable sur téléphone.

## 3. Périmètre

**Inclus**
- Loi n° 2017-20 du 20 avril 2018 portant Code du numérique en République du Bénin.
- Loi n° 2018-16 portant Code pénal en République du Bénin.
- Questions en français portant sur l'usage du numérique : vie privée, données personnelles, cybercriminalité, infractions en ligne, sanctions.

**Exclus**
- Conseil juridique personnalisé, rédaction d'actes, assistance à une procédure.
- Textes non fournis dans le corpus (lois modificatives, décrets d'application, jurisprudence).
- Langues autres que le français (évolution possible).

## 4. Utilisateurs cibles

- Citoyens et jeunes internautes confrontés à une situation en ligne.
- Étudiants, journalistes, associations qui cherchent rapidement un article.
- Aucune compétence technique ni juridique requise.

## 5. Exigences fonctionnelles

| Réf. | Exigence | Priorité |
|---|---|---|
| EF1 | Saisir une question en texte libre dans une interface de type conversation | Obligatoire |
| EF2 | Retrouver automatiquement les articles les plus pertinents dans le corpus | Obligatoire |
| EF3 | Rédiger une réponse en langage simple, uniquement à partir des articles retrouvés | Obligatoire |
| EF4 | Citer la loi et le numéro d'article pour chaque affirmation | Obligatoire |
| EF5 | Afficher le texte des articles utilisés, dans une section dépliable | Obligatoire |
| EF6 | Refuser de répondre, de façon explicite, lorsqu'aucun article pertinent n'est trouvé | Obligatoire |
| EF7 | Afficher en permanence un avertissement : information générale, pas un avis juridique | Obligatoire |
| EF8 | Reformuler la question avec le vocabulaire juridique pour améliorer la recherche | Souhaitable |
| EF9 | Proposer des exemples de questions et permettre de recommencer une conversation | Souhaitable |
| EF10 | Basculer sur un modèle de secours en cas d'indisponibilité du modèle principal | Souhaitable |

## 6. Exigences non fonctionnelles

- **Fiabilité** : aucune référence à un article absent du corpus ; montants et durées repris tels qu'écrits dans les textes.
- **Performance** : temps de réponse compatible avec un usage grand public.
- **Confidentialité** : ne pas demander ni conserver de données personnelles ; informer l'utilisateur que ses questions sont traitées par un service de modèle de langage externe ; clés d'accès conservées hors du code source.
- **Accessibilité** : interface en français, lisible, adaptée au téléphone.
- **Maintenabilité** : code modulaire et documenté ; ajout de nouveaux textes de loi sans refonte.
- **Coût** : fonctionnement avec des services gratuits ou à faible coût en phase de prototype.

## 7. Architecture technique prévue

1. **Ingestion** : lecture des PDF, nettoyage du texte, découpage par article.
2. **Indexation** : représentation vectorielle des articles (embeddings multilingues) et index lexical complémentaire.
3. **Recherche hybride** : combinaison de la recherche sémantique et de la recherche par mots-clés.
4. **Re-classement** : second modèle qui ordonne les articles par pertinence et filtre ceux qui sont insuffisants.
5. **Génération** : modèle de langage (API Gemini) contraint de répondre à partir du contexte retrouvé et de citer ses sources.
6. **Interface** : application web Streamlit.
7. **Déploiement** : dépôt GitHub, publication sur Streamlit Community Cloud, secrets gérés par la plateforme.

**Technologies** : Python, Streamlit, sentence-transformers, FAISS, PyTorch, API Gemini, GitHub.

## 8. Évaluation et critères d'acceptation

| Critère | Méthode | Objectif visé |
|---|---|---|
| Pertinence de la recherche | Jeu de questions annotées avec l'article attendu ; mesures Hit@k et MRR | Choisir la configuration la plus performante |
| Fidélité des réponses | Relecture manuelle de réponses contre les articles cités | Au moins 95 % de réponses fidèles |
| Exactitude des citations | Vérification de chaque article cité dans le texte source | Au moins 95 % de citations correctes |
| Refus hors corpus | Questions sans réponse dans les textes | Aucune réponse inventée |
| Disponibilité | Test de l'application publiée | Accessible par une URL et sans erreur au démarrage |

## 9. Livrables

- Code source dans un dépôt GitHub, avec fichier de dépendances et README.
- Corpus des textes de loi et index de recherche.
- Notebook documenté (méthode, évaluation, limites).
- Application web déployée et accessible par URL.
- Rapport d'évaluation.
- Le présent cahier des charges.

## 10. Planning prévisionnel *(à adapter)*

| Phase | Contenu | Échéance |
|---|---|---|
| 1 | Constitution du corpus et pipeline de recherche | *à compléter* |
| 2 | Génération des réponses avec citation et refus | *à compléter* |
| 3 | Évaluation et ajustements | *à compléter* |
| 4 | Application Streamlit, dépôt GitHub | *à compléter* |
| 5 | Déploiement, tests avec des utilisateurs, corrections | *à compléter* |

## 11. Risques et mesures

| Risque | Mesure prévue |
|---|---|
| Réponse inexacte ou inventée | Réponse limitée au contexte retrouvé, citation obligatoire, refus explicite |
| Textes incomplets ou modifiés depuis | Indiquer les limites du corpus ; ajouter les textes modificatifs |
| Erreurs dans les PDF sources | Citer le texte tel quel et signaler les incohérences |
| Quota ou indisponibilité du service de modèle de langage | Modèle de secours, mise en cache, possibilité de clé payante |
| Ressources limitées de l'hébergement gratuit | Version allégée ou hébergement plus adapté |
| Mauvaise interprétation par l'utilisateur | Avertissement permanent, article cité systématiquement |
| Saisie de données personnelles sensibles | Mise en garde dans l'interface, aucune conservation |
| Jeu d'évaluation trop petit | Élargir et diversifier les questions de test |

## 12. Contraintes

- Réponses fondées exclusivement sur le corpus officiel fourni.
- Respect de la législation sur la protection des données personnelles.
- Hébergement et services gratuits ou peu coûteux pendant le prototype.

## 13. Évolutions possibles

- Ajout des lois modificatives et des décrets d'application.
- Support de l'anglais et des langues locales.
- Saisie vocale pour les utilisateurs peu lecteurs.
- Retour utilisateur sur la qualité des réponses.
- Extension à d'autres domaines du droit.

## 14. Validation

| Rôle | Nom | Date | Signature |
|---|---|---|---|
| Porteur du projet | | | |
| Encadrant / client | | | |
