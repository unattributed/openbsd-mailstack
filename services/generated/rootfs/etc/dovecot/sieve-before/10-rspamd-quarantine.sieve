require ["fileinto", "mailbox"];

# Route server-labeled suspicious mail into Junk before user mailboxes sync.
if header :is "X-BBS-Quarantine" "Junk" {
  fileinto :create "Junk";
  stop;
}
