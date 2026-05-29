import dotenv from 'dotenv'
import { z } from 'zod'

dotenv.config()

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(8080),
  CORS_ORIGIN: z.string().default('http://localhost:3000'),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
  FIREBASE_PROJECT_ID: z.string().min(1, 'nexalgo-ace83'),
  FIREBASE_CLIENT_EMAIL: z.string().email('nexalgo-ace83@nexalgo-ace83.iam.gserviceaccount.com'),
  FIREBASE_PRIVATE_KEY: z.string().min(1, '-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDW+hdOyDThprTR\nczQtq5mmNXghkI+p5Xdb7IE4EhaCRtowqmsuA68uwj8cIVy1t+92PLoZsJagh1no\n1f4AFa/c4d6oEw/zrJvifvwKb4GUCtmz5SJmAR1E+wmkaq0oP2RzjETRStl/+UrT\nkFx7LnGXiPR9uOmHevbHne0C++wGuGAut57Brl7rTIQnShUKH3iLOmeDjlK/Xevz\nL/G4nybiTVHDDoVIwQeo14E6mLlr4yWpNZqC1XOJATb2/Mil3KS6S/Z7YrZvzMKO\nmZc9znijfAuc/RQJOkNr5qD9Urz7sqQx4DBzKUyIeRDUHREqIZ7i+yrWE0Eu3NGL\npGxE65s9AgMBAAECggEAE0rLn1elhz/n/N6TJtYTf9r54Ok8O0mgddtk7Uc88IwI\ni1LVM4KZIgpvPMhcWDfILEWJiJdUV9ZNt0Yc+Uejn0rrKbeBjaNGigOjUrxsVdYe\nG2Agv3lcyxKhluO2jmTB+wHyMGYV3BTfJi/6XK5E+2MLAzf+R8OSie9zlE+kqtA5\ni6qemzAJvNIFrTZbiduWo4TMODvXxWQRkZoqgis7kaSFM+67Uf3HTtxOwKDTjpzQ\nvPhBF+8BVT7s4H6yqqLySe94AO4x9RGuL2D8HClGJoZLJ9jEB3hQ6rwaQr9irqJV\n5FFn4twJLBpcUqIM77M/QxocIX+Puy5PnFScUr1NcQKBgQD1SsxtxqiRmSHUx/Cv\nKK2IUmLEvXvvD3/hKBZ5cL314c9EOZuNLi7pfPYpyJ3V2I8esIBKWFtDWVSXZSmV\nEreCjy/sCu+v9/3Ft84jWVguV5pJ1KcWNIaDNizoB86Cq1bCYf95J8vkEnclAJ/b\nmtqqqxL8RFfaxsFfDJibcnKdXwKBgQDgXIMIVY+ZVzn0wnl1qEJEwysaofhjhGei\nbbrde3TglTyUZQE/6/o8upv5u7R7e2agkzeECuapaf1vIlreqsD61tJdpYPngiek\nZysPuqxlWaze0ubqJWqMtu3L0CCTFIlrAuwyyPWx7e6EtavF/rMfHxDIcRIchcqJ\n4twUwN/w4wKBgCqfgL5iktAaB+Lti0kkjGLvzfHZ6zszOklpqd4YVSnwvw9f40O5\nDrXL3QqNrb+HDfeLO/+vMsyVLTnRflRFGFY7g1xE2jl9oj9FHTDPSZ9j4Y+KwC3/\nmpAaTdtT3/Kcy0qjtLzcyXUsMD/hx+VlFzIo3/et+IYvm1Jk4e/BB2GJAoGAEMH4\nK4QwgJSKSKTJ66bQpFArhQa6Bbza/L/TaD2TYj7jUnYk3MBkZWrOwZ1qgpqZ9L5q\nNBuYVOkMu+NGBEGevl2TQtlc+8q16UqnZbpcrAlBpzb7dlurFK2JH2MBO9sZ1HtY\nZwapi0upOBJVrSkz+cwZNc90OdsoYJooNAif8V8CgYAoBaFfG7Ewcn1ZW4GK20nR\nQFSSoL/QAazpszNTanoOO/OQol/DX/j+E0izSt108JdRfERNVIxdTEH2m7WSl9UU\nXBO69xHcnVJkL/lJQr8OondTxJULYzm/DnjERMcExxJEc/W/JtUK4XKF8iIPvI9u\nuM2ffO0OJDEr2kIUPodeEQ==\n-----END PRIVATE KEY-----\n'),
  OPENAI_API_KEY: z.string().optional(),
  OPENAI_MODEL: z.string().default('gpt-5-mini'),
  NEXALGO_INITIAL_ADMIN_EMAIL: z.string().email().optional(),
})

export const env = envSchema.parse(process.env)
