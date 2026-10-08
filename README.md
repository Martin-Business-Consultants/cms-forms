# Forms

A plugin for the CMS (see `docs/plugins.md` in [LibrePublish CMS](https://github.com/Martin-Business-Consultants/cmsv2)).

Install it into a CMS checkout:

    bin/rails "plugins:install[<this repository's git URL>]"

or, on a Docker install, add the URL to the `CMS_PLUGINS` builder secret.

Its specs run inside the CMS, with the plugin installed in `plugins/forms`:

    bin/rspec plugins/forms/spec
