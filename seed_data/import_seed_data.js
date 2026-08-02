/**
 * Imports PantunConnect seed content into Firestore.
 *
 * Seeds:
 *  - users/seed_curator_01                    (pantunconnect_seed_curator_user.json)
 *  - posts/<auto-id>  x 5,642 (full corpus)   (pantunconnect_seed_posts_full.json)
 *    or x 60 (curated sample)                 (pantunconnect_seed_posts.json, via --sample)
 *
 * The full corpus is every unique pantun from the "Klasifikasi Pantun Kurik Kundi Merah Saga -
 * 6 Tema Baharu" research dataset (5,644 rows, 5,642 unique), tagged with the same 6-theme
 * taxonomy the "Smart Post Creator" AI classifier uses. Timestamps are spread across the past
 * two years so fresh user posts always appear above the seeded corpus in the feed.
 *
 * IDEMPOTENT: existing posts by seed_curator_01 are deleted before importing, so re-running
 * never creates duplicates (and switching between --sample and full just replaces the set).
 *
 * SETUP (one-time):
 *   1. Firebase Console > Project Settings > Service Accounts > Generate new private key.
 *      Save the downloaded file next to this script as "serviceAccountKey.json".
 *      (Do NOT commit this file to git - it grants full admin access to your Firebase project.)
 *   2. npm install firebase-admin
 *
 * RUN:
 *   node import_seed_data.js            # full 5,642-pantun corpus
 *   node import_seed_data.js --sample   # the 60-pantun curated sample instead
 */

// Modular API (firebase-admin/app + firebase-admin/firestore) instead of the legacy
// `admin.credential.cert` namespace - the legacy entry point breaks on Node 22+ (require()
// resolves the package's ESM build, leaving `admin.credential` undefined).
const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const serviceAccount = require("./serviceAccountKey.json");
const curatorUser = require("./pantunconnect_seed_curator_user.json");

const useSample = process.argv.includes("--sample");
const posts = require(useSample ? "./pantunconnect_seed_posts.json" : "./pantunconnect_seed_posts_full.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();
const CHUNK = 400; // Firestore batches allow max 500 ops

async function deleteExistingCuratorPosts() {
  console.log("Removing previous seed posts (if any)...");
  let removed = 0;
  for (;;) {
    const snapshot = await db
      .collection("posts")
      .where("authorId", "==", curatorUser.id)
      .limit(CHUNK)
      .get();
    if (snapshot.empty) break;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    removed += snapshot.size;
    process.stdout.write(`  removed ${removed}\r`);
  }
  console.log(`  removed ${removed} old seed posts.`);
}

async function main() {
  console.log(`Mode: ${useSample ? "curated sample (60)" : "FULL corpus"} - ${posts.length} posts`);

  console.log("Seeding curator user...");
  await db.collection("users").doc(curatorUser.id).set(curatorUser);

  await deleteExistingCuratorPosts();

  console.log(`Seeding ${posts.length} posts in chunks of ${CHUNK}...`);
  for (let i = 0; i < posts.length; i += CHUNK) {
    const batch = db.batch();
    posts.slice(i, i + CHUNK).forEach((post) => {
      // Strip the debug-only fields before writing (not part of the Post model).
      const { _sourceNoAsal, _sourceNegeri, ...postData } = post;
      const ref = db.collection("posts").doc();
      batch.set(ref, { ...postData, id: ref.id });
    });
    await batch.commit();
    console.log(`  ${Math.min(i + CHUNK, posts.length)} / ${posts.length}`);
  }

  console.log(`Done. Seeded 1 user + ${posts.length} posts.`);
}

main().catch((err) => {
  console.error("Seed import failed:", err);
  process.exit(1);
});
