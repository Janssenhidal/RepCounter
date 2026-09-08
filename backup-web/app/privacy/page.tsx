/* eslint-disable next/no-html-link-for-pages -- Use full document navigation until client routing is reliable. */
// eslint-disable-next-line next/no-html-link-for-pages -- Document navigation avoids a vinext client-router failure.
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Privacy Policy — Rep Counter',
  description: 'How Rep Counter handles watch data and optional backup transfers.',
};

export default function PrivacyPage() {
  return (
    <main className="backup-shell privacy-page">
      <header><a className="brand" href="/">REP COUNTER</a><span className="badge">PRIVACY</span></header>
      <h1>Privacy policy</h1>
      <p>Last updated: 8 September 2026</p>
      <p className="intro">Your workouts stay on your watch unless you use Backup / Export. That feature sends a temporary copy to our backup service so you can download or restore it.</p>
      <h2>Who is responsible</h2>
      <p>Rep Counter and backup.execureach.co are operated by Janssenhidal. For privacy questions or requests, contact <a href="mailto:janssen@execureach.co">janssen@execureach.co</a>.</p>
      <p>Data sent to this backup service is submitted to the operator of Rep Counter, not to Garmin. Garmin is not responsible or liable for that data. Garmin Connect and the Connect IQ Store have their own privacy policies.</p>
      <h2>Data on your watch</h2>
      <p>The app stores your rep and set counts, workout and set timestamps, current workout, rest timer, increment, rest duration, and vibration preference on your watch. Ordinary counting and history browsing do not require our backup service. The app does not read GPS location, heart rate, contacts, or your Garmin account credentials.</p>
      <h2>Optional backup and restore</h2>
      <p>Opening Backup / Export starts a transfer and uploads your available workout history, current workout, and preferences. You do not have to enter the code on the website for that upload to begin. When restoring, the JSON file you upload is also sent to the service.</p>
      <p>We use these records to create your JSON backup or CSV report and to send a selected backup back to your watch. Temporary pairing codes and access tokens connect your watch and browser. No Rep Counter account is required. Keep your pairing code private.</p>
      <h2>Technical data and hosting</h2>
      <p>Cloudflare hosts the website and transfer service. It receives connection information such as IP addresses and request metadata to deliver and protect the service. Our application uses a hash derived from the IP address to limit repeated pairing attempts; this is a technical identifier, not a guarantee of anonymity.</p>
      <p>Cloudflare may process data outside your country. Its processing, international transfer arrangements, and applicable retention practices are described in the <a href="https://www.cloudflare.com/privacypolicy/">Cloudflare privacy policy</a>. The backup application does not add advertising trackers or analytics cookies, sell workout data, or use workout data for advertising or AI training.</p>
      <h2>How long data is kept</h2>
      <p>A transfer expires 15 minutes after it is created. After expiry it is no longer accessible through the transfer API, and automatic cleanup removes it from active application storage. Cleanup can be delayed by service availability. An explicit successful close request also removes the active transfer.</p>
      <p>Rate-limit counters use one-minute windows and are scheduled for cleanup. Cloudflare technical logs and platform recovery copies may remain longer under its service retention rules. The 15-minute expiry is not a promise that every infrastructure copy is immediately erased.</p>
      <p>History on your watch remains until deleted, replaced by a restore, or removed with app data. Downloaded files remain wherever you save them; we cannot delete those copies for you.</p>
      <h2>Your choices and rights</h2>
      <p>You can use the counter without opening Backup / Export. You can delete completed workouts on the watch, download your data, and delete downloaded files from your devices. Closing the page alone does not guarantee immediate deletion of a transfer; its expiry still applies.</p>
      <p>Where applicable, data protection law gives you rights to access, correct, erase, or receive your personal data, restrict or object to processing, and complain to your local data protection authority. Contact us to make a request. Because transfers are temporary and do not use accounts, we may need enough information to identify a transfer and verify your request. Do not email your workout backup or access token unless we agree on a suitable way to handle it.</p>
      <h2>Changes</h2>
      <p>We will update this page when our data handling changes and revise the date above.</p>
      <footer><a href="/">Back to backup &amp; restore</a></footer>
    </main>
  );
}



