# Distribuer l'application Android par Firebase App Distribution

But : envoyer le fichier `.apk` de NetBuis à des testeurs (lien ou e-mail), sans passer par le Play Store. **Rien n'a été essayé** : ni la construction de l'APK, ni l'envoi (pas de SDK Android ni d'accès Firebase depuis la session de travail).

L'application n'embarque **pas** le SDK Firebase : App Distribution n'exige donc ni `google-services.json` ni changement du code. Seul l'identifiant de l'application Android dans la console Firebase compte.

## 1. Préparer Firebase (console, une fois)
1. console.firebase.google.com → **Ajouter un projet** (Analytics inutile).
2. Paramètres du projet → **Ajouter une application → Android** → nom du package : **`cm.netbuis.netbuis`** (celui de `mobile/android/app/build.gradle.kts`). Pas besoin de télécharger `google-services.json`.
3. Menu **Release et surveillance → App Distribution → Commencer**. Créer un groupe de testeurs d'alias **`testeurs`** et y ajouter les adresses e-mail.
4. Noter l'**identifiant de l'application** (Paramètres du projet → Vos applications → « ID de l'application », de la forme `1:123456789:android:abcdef…`).

## 2. Autoriser GitHub à envoyer l'APK (clé de service)
1. Console Google Cloud (même projet) → IAM et administration → **Comptes de service** → créer `netbuis-distribution` avec le rôle **Administrateur Firebase App Distribution** (`roles/firebaseappdistro.admin`).
2. Onglet Clés → Ajouter une clé → JSON : le fichier téléchargé est un **secret** : ne le mettez ni dans le dépôt ni dans un message.
3. GitHub → Settings → Secrets and variables → Actions :
   - secret `FIREBASE_SERVICE_ACCOUNT_JSON` = tout le contenu du fichier JSON ;
   - secret `FIREBASE_APP_ID` = l'identifiant noté en 1.4 ;
   - secret `NETBUIS_API_URL` = `https://VOTRE-SERVEUR/api` (adresse du serveur, avec `/api`) ;
   - (facultatif) variable `FIREBASE_TESTER_GROUP` si l'alias du groupe n'est pas `testeurs`.
4. Supprimer le fichier JSON de votre ordinateur une fois le secret enregistré.

## 3. Envoyer une version
GitHub → onglet **Actions** → workflow **CI** → **Run workflow** → cocher « Envoyer l'APK aux testeurs » → Run. La tâche « APK Android » construit l'APK (signature de débogage) puis l'envoie ; les testeurs reçoivent un e-mail avec le lien d'installation (Firebase leur demande d'installer l'application « App Tester »).

## 4. Sans GitHub (depuis votre ordinateur)
```
cd mobile && flutter build apk --release --dart-define=API_URL=https://VOTRE-SERVEUR/api
npm install -g firebase-tools && firebase login
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --app ID_DE_L_APPLICATION --groups testeurs
```

## Limites
- Signature de **débogage** : suffisant pour des essais, pas pour le Play Store (clé de production à créer, hors du dépôt).
- Le serveur doit être en ligne en `https` avant que les testeurs ouvrent l'application (voir `docs/deployment/GUIDE_JEFF.md`). Les appels demandent en plus un serveur Jitsi (`docs/deployment/JITSI.md`).
- Taille de l'APK : le SDK Jitsi l'alourdit ; à mesurer.
