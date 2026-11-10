// Command castor casts over the public API, composing missing services in its own process.
package main

import (
	"os"
	"slices"

	"github.com/urfave/cli/v3"

	"github.com/stupside/castor/cmd/internal/process"
	"github.com/stupside/castor/services/apiserver"
	"github.com/stupside/castor/services/mediaserver"
	"github.com/stupside/castor/services/scrapingserver"
)

func init() {
	if os.Getenv("SSL_CERT_FILE") == "" {
		for _, path := range []string{"/private/etc/ssl/cert.pem", "/etc/ssl/cert.pem", "/etc/ssl/certs/ca-certificates.crt"} {
			if _, err := os.Stat(path); err == nil {
				os.Setenv("SSL_CERT_FILE", path)
				break
			}
		}
	}
}

func main() {
	local := Local(apiserver.Embedded(mediaserver.Embedded, scrapingserver.Embedded))
	process.Run(&cli.Command{
		Name:     "castor",
		Usage:    "Cast video streams to networked devices",
		Commands: slices.Concat(Commands(local), []*cli.Command{apiserver.Command(), mediaserver.Command(), scrapingserver.Command()}),
	}, func(cmd *cli.Command) bool {
		// Printing a direct URL is entirely local and deliberately ignores config.
		return cmd.Name != "url" || !cmd.Bool(dryRunFlag)
	})
}
