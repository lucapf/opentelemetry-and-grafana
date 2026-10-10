from fastapi import FastAPI
import logging


app = FastAPI()

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


@app.get("/hello-world")
async def root():
    logger.info("inside the hello world")
    return {"message": "Hello World"}
