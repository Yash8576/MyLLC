const RESUME_PATH = '/resume/Yaswanth_Dammalapati_SDE.pdf'

export default function ResumeViewerContent() {
  return (
    <main className='bg-white px-0 pb-12 pt-28 md:pb-16 md:pt-32'>
      <div className='mx-auto w-[92%] max-w-6xl'>
        <div className='mb-6 flex flex-col gap-4 md:mb-8 md:flex-row md:items-center md:justify-between'>
          <div>
            <h1 className='text-3xl font-bold text-midnight_text md:text-4xl'>Resume</h1>
            <p className='mt-2 text-base text-black/70'>
              View the resume below or download a copy.
            </p>
          </div>

          <a
            href={RESUME_PATH}
            download
            className='inline-flex w-fit items-center rounded-md bg-primary px-5 py-3 text-sm font-semibold text-white transition-opacity duration-300 hover:opacity-90'>
            Download Resume
          </a>
        </div>

        <div className='mb-6 rounded-xl border border-black/10 bg-slate-gray p-5 shadow-sm md:hidden'>
          <p className='text-sm leading-6 text-black/75'>
            Mobile browsers handle PDF controls better in a separate viewer. Open the
            resume in a new tab there to pinch-zoom and read comfortably.
          </p>
          <div className='mt-4 flex flex-wrap gap-3'>
            <a
              href={RESUME_PATH}
              target='_blank'
              rel='noreferrer'
              className='inline-flex items-center rounded-md bg-primary px-5 py-3 text-sm font-semibold text-white transition-opacity duration-300 hover:opacity-90'>
              Open Resume
            </a>
            <a
              href={RESUME_PATH}
              download
              className='inline-flex items-center rounded-md border border-primary/20 bg-white px-5 py-3 text-sm font-semibold text-primary transition-colors duration-300 hover:bg-primary/5'>
              Download PDF
            </a>
          </div>
        </div>

        <div className='hidden overflow-hidden rounded-xl border border-black/10 shadow-sm md:block'>
          <iframe
            src={`${RESUME_PATH}#toolbar=1&navpanes=0`}
            title='Resume PDF'
            className='h-[72vh] w-full min-h-[540px]'
          />
        </div>
      </div>
    </main>
  )
}
