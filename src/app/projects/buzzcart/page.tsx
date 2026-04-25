import Link from 'next/link'

const deploymentItems = [
  'Flutter web frontend deployed separately to Firebase Hosting',
  'Go backend deployed to Cloud Run with Cloud SQL PostgreSQL',
  'Firebase Storage / GCS bucket for media and product files',
  'Redis treated as optional',
  'Chatbot and Ollama intentionally disabled in production',
]

export default function BuzzCartProjectPage() {
  return (
    <main className='bg-slate-gray min-h-screen py-24'>
      <div className='container max-w-5xl'>
        <div className='bg-white rounded-3xl shadow-card-shadow p-8 md:p-12 space-y-10'>
          <div className='space-y-4'>
            <span className='inline-flex rounded-full bg-primary/10 px-4 py-2 text-sm font-medium text-primary'>
              Nexacore Owned
            </span>
            <div className='space-y-3'>
              <h1 className='text-midnight_text'>BuzzCart</h1>
              <p className='text-black/70 text-lg max-w-3xl'>
                BuzzCart is a social commerce application operated from this
                repo as a standalone project. The frontend stays Flutter web,
                the backend stays Go, and production remains Cloud Run plus
                Firebase rather than the chatbot stack.
              </p>
            </div>
          </div>

          <section className='space-y-4'>
            <h2 className='text-midnight_text text-2xl'>Production Shape</h2>
            <div className='grid gap-4 md:grid-cols-2'>
              {deploymentItems.map((item) => (
                <div key={item} className='rounded-2xl bg-slate-gray p-5 text-black/70'>
                  {item}
                </div>
              ))}
            </div>
          </section>

          <section className='space-y-4'>
            <h2 className='text-midnight_text text-2xl'>Where To Work</h2>
            <div className='rounded-2xl border border-black/10 p-6 space-y-4'>
              <p className='text-black/70'>
                Engineers should use the BuzzCart project folder for code,
                deployment docs, and operational scripts.
              </p>
              <div className='rounded-2xl bg-slate-gray p-5 text-black/70'>
                <p className='font-semibold text-midnight_text'>Repo path</p>
                <p className='mt-2 font-mono text-sm'>projects/buzzcart</p>
                <p className='mt-3 text-sm'>
                  The production app is published at <span className='font-mono'>/nexacore/BuzzCart/</span>
                  on the same Cloudflare Pages site. Deployment details live in
                  the BuzzCart README, Cloud Run guide, Pages build script, and
                  repo workflows.
                </p>
              </div>
              <div className='flex flex-wrap gap-3'>
                <Link
                  href='/nexacore/BuzzCart'
                  className='rounded-full bg-primary px-5 py-3 text-sm font-medium text-white transition-opacity hover:opacity-90'>
                  Open App
                </Link>
                <Link
                  href='/nexacore/BuzzCart/Login'
                  className='rounded-full border border-black/10 px-5 py-3 text-sm font-medium text-midnight_text transition-colors hover:bg-slate-gray'>
                  Login
                </Link>
                <Link
                  href='/nexacore/BuzzCart/Signup'
                  className='rounded-full border border-black/10 px-5 py-3 text-sm font-medium text-midnight_text transition-colors hover:bg-slate-gray'>
                  Signup
                </Link>
              </div>
            </div>
          </section>

          <section className='space-y-3'>
            <h2 className='text-midnight_text text-2xl'>Repo Integration</h2>
            <p className='text-black/70'>
              The repo now includes project-specific GitHub Actions for BuzzCart
              validation and deployment, Firebase Hosting configuration for the
              web app, and Cloud Run deployment templates for the backend.
            </p>
          </section>
        </div>
      </div>
    </main>
  )
}
