import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

const root = createRoot(document.getElementById('root')!);
// Catch missing build configuration without showing a blank page or secrets.
void import('./App').then(({ App }) => {
  root.render(<React.StrictMode><App /></React.StrictMode>);
}).catch(() => {
  root.render(<main className="portal-login" role="alert"><h1>Panel şu anda açılamıyor</h1><p>Lütfen daha sonra tekrar deneyin veya topluluk yöneticinize bildirin.</p></main>);
});
