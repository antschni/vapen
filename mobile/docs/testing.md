# Manual test checklist (Android)

- [ ] Login against seeded API (`alice@example.com` / `vapen-demo-password`)
- [ ] Pairing with simulated device uploads puffs to API
- [ ] App swiped away — foreground notification remains, uploads continue
- [ ] Reboot with tracking enabled — service restarts (where OS allows)
- [ ] Airplane mode 1 h — events buffered, no duplicates after reconnect
- [ ] InnoGate parallel — hint shown when connection fails (when real BLE wired)
- [ ] Group live SSE updates on simulated ingest
- [ ] Battery drain target: &lt; 3 % / day from Vapen (8 h sample)
