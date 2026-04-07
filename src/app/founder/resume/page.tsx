const RESUME_PATH = '/resume/Yaswanth_Ravi_Teja_Dammalapati_Software_Engineer.pdf'

export default function ResumePage() {
  return (
    <main className='bg-white py-12 md:py-16'>
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

        <div className='overflow-hidden rounded-xl border border-black/10 shadow-sm'>
          <iframe
            src={RESUME_PATH}
            title='Resume PDF'
            className='h-[72vh] w-full min-h-[540px]'
          />
        </div>
      </div>
    </main>
  )
}
