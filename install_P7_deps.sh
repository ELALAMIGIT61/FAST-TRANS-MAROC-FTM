#!/bin/bash
cd /workspaces/FAST-TRANS-MAROC-FTM/frontend
npm audit fix
npm audit fix --force
echo "✅ P7 deps et vulnerabilities traités"