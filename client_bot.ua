from aiogram import Bot, Dispatcher, types
from aiogram.types import ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.utils import executor
from aiogram.contrib.fsm_storage.memory import MemoryStorage
from aiogram.dispatcher import FSMContext
from aiogram.dispatcher.filters.state import State, StatesGroup
import requests

API_TOKEN = '7601039938:AAFBwVCYTOjPWq0PGMi4RWn9D7jPUpH1tgw'
ADMIN_BOT_TOKEN = '8025761375:AAFy7cXEiTrQUhF7_x3ks6qB6veQAJn_0yc'
ADMIN_CHAT_ID = 1354155194

bot = Bot(token=API_TOKEN)
dp = Dispatcher(bot, storage=MemoryStorage())

class OrderForm(StatesGroup):
    choosing_payment = State()
    entering_name = State()
    entering_phone = State()
    entering_address = State()

menu = {
    "Сукні": ["Біле плаття 💫 — 1200₴", "Рожеве плаття 🌸 — 1350₴", "Нюдове плаття 🍑 — 1100₴"]
}

cart = {}
orders = {}
order_id_map = {}
pending_choice = {}

main_kb = ReplyKeyboardMarkup(resize_keyboard=True)
main_kb.add("🛍 Меню", "🛒 Кошик").add("📦 Мої замовлення")

after_size_kb = ReplyKeyboardMarkup(resize_keyboard=True)
after_size_kb.add("➕ Додати ще", "🛒 Перейти до кошика")

payment_kb = ReplyKeyboardMarkup(resize_keyboard=True)
payment_kb.add("💳 100% оплата", "💰 50% передплата", "💵 300₴ аванс").add("🔙 Назад")

item_details = {
    "Біле плаття 💫 — 1200₴": {
        "photo": "AgACAgIAAxkBAAPfaIv-f6gCK5_jVSM3f6UyDIxPRJMAAvzzMRury2FIAQ27gbmfas0BAAMCAAN5AAM2BA",
        "desc": "Ніжне біле плаття, ідеальне для літа ☀️",
    },
    "Рожеве плаття 🌸 — 1350₴": {
        "photo": "https://example.com/pink.jpg",
        "desc": "Романтичне рожеве плаття з легким шлейфом 🌷",
    },
    "Нюдове плаття 🍑 — 1100₴": {
        "photo": "https://example.com/nude.jpg",
        "desc": "Лаконічне нюдове плаття для будь-якого заходу 🎀",
    }
}

def build_admin_kb(order_id: str):
    return InlineKeyboardMarkup(row_width=2).add(
        InlineKeyboardButton("✅ Прийняти", callback_data=f"approve_{order_id}"),
        InlineKeyboardButton("❌ Відхилити", callback_data=f"reject_{order_id}")
    )

@dp.message_handler(commands=['start'])
async def start(msg: types.Message):
    await msg.answer("Привіт, красуне! 👗 Я — твій магазин стильного одягу і допоможу оформити замовлення. Обери опцію нижче:", reply_markup=main_kb)

@dp.message_handler(lambda m: m.text == "🛍 Меню")
async def show_menu(msg: types.Message):
    kb = ReplyKeyboardMarkup(resize_keyboard=True)
    for cat in menu:
        kb.add(cat)
    kb.add("🔙 Назад")
    await msg.answer("Обери категорію:", reply_markup=kb)

@dp.message_handler(lambda m: m.text in menu)
async def show_items(msg: types.Message):
    items = menu[msg.text]
    kb = ReplyKeyboardMarkup(resize_keyboard=True)
    for item in items:
        kb.add(item)
    kb.add("🔙 Назад")
    await msg.answer("Оберіть товар:", reply_markup=kb)

@dp.message_handler(lambda m: m.text in sum(menu.values(), []))
async def show_item_details(msg: types.Message):
    user_id = msg.from_user.id
    item = msg.text
    pending_choice[user_id] = item

    data = item_details.get(item)
    if not data:
        await msg.answer("Фото недоступне.")
    else:
        buttons = [
            [KeyboardButton("S"), KeyboardButton("M"), KeyboardButton("L")],
            [KeyboardButton("🔙 Назад")]
        ]
        kb = ReplyKeyboardMarkup(resize_keyboard=True, keyboard=buttons)
        await msg.answer_photo(
            photo=data["photo"],
            caption=f"{data['desc']}

Оберіть розмір:",
            reply_markup=kb
        )

@dp.message_handler(lambda m: m.text in ["S", "M", "L"])
async def choose_size(msg: types.Message):
    user_id = msg.from_user.id
    item = pending_choice.get(user_id)
    if not item:
        await msg.answer("❗ Спочатку оберіть товар.")
        return
    cart.setdefault(user_id, []).append(f"{item} (Розмір {msg.text})")
    del pending_choice[user_id]

    await msg.answer(f"✨ Додано до кошика: {item} (Розмір {msg.text})", reply_markup=after_size_kb)

@dp.message_handler(lambda m: m.text == "🛒 Кошик")
async def show_cart(msg: types.Message):
    user_id = msg.from_user.id
    items = cart.get(user_id, [])
    if not items:
        await msg.answer("Кошик порожній 🧺")
        return
    text = "\n".join(f"{i+1}. {item}" for i, item in enumerate(items))
    await msg.answer(f"🛒 Ваш кошик:\n{text}\n\nОформити: /order")

@dp.message_handler(commands=['order'])
async def order_start(msg: types.Message, state: FSMContext):
    user_id = msg.from_user.id
    items = cart.get(user_id, [])
    if not items:
        await msg.answer("Кошик порожній!")
        return

    total = 0
    for i in items:
        # Extract price
        try:
            price_str = i.split('—')[-1].replace("₴", "").strip()
            total += int(price_str)
        except:
            pass

    summary = "\n".join(f"— {item}" for item in items)
    await state.update_data(cart=items)

    await OrderForm.choosing_payment.set()
    await msg.answer(f"🧾 *Поточне замовлення:*\n{summary}\n💰 *Сума:* {total}₴\n\nОберіть спосіб оплати:",
                     parse_mode="Markdown", reply_markup=payment_kb)

@dp.message_handler(lambda m: m.text == "🔙 Назад", state='*')
async def go_back(msg: types.Message, state: FSMContext):
    current_state = await state.get_state()

    if current_state == OrderForm.entering_address.state:
        await OrderForm.entering_phone.set()
        await msg.answer("⬅️ Введіть номер телефону ще раз:")
    elif current_state == OrderForm.entering_phone.state:
        await OrderForm.entering_name.set()
        await msg.answer("⬅️ Введіть ім’я ще раз:")
    elif current_state == OrderForm.entering_name.state:
        await OrderForm.choosing_payment.set()
        await msg.answer("⬅️ Оберіть спосіб оплати ще раз:", reply_markup=payment_kb)
    elif current_state == OrderForm.choosing_payment.state:
        await msg.answer("↩️ Назад далі неможливо.", reply_markup=main_kb)

@dp.message_handler(state=OrderForm.choosing_payment)
async def ask_name(msg: types.Message, state: FSMContext):
    await state.update_data(payment=msg.text)
    await OrderForm.entering_name.set()
    await msg.answer("Введіть ім’я:", reply_markup=payment_kb)

@dp.message_handler(state=OrderForm.entering_name)
async def ask_phone(msg: types.Message, state: FSMContext):
    await state.update_data(name=msg.text)
    await OrderForm.entering_phone.set()
    await msg.answer("Введіть номер телефону:", reply_markup=payment_kb)

@dp.message_handler(state=OrderForm.entering_phone)
async def ask_address(msg: types.Message, state: FSMContext):
    await state.update_data(phone=msg.text)
    await OrderForm.entering_address.set()
    await msg.answer("Введіть адресу доставки:", reply_markup=payment_kb)

@dp.message_handler(state=OrderForm.entering_address)
async def confirm_order(msg: types.Message, state: FSMContext):
    user_id = msg.from_user.id
    data = await state.get_data()
    items = data.get("cart", [])
    order = {
        "items": items,
        "payment": data["payment"],
        "name": data["name"],
        "phone": data["phone"],
        "address": msg.text,
        "status": "очікує"
    }
    orders.setdefault(user_id, []).append(order)
    order_id = f"{user_id}-{len(orders[user_id])}"
    order_id_map[order_id] = (user_id, len(orders[user_id]) - 1)
    cart[user_id] = []

    ext = "\n".join(items)
    await msg.answer(f"🌸 Замовлення оформлено!\n🆔 {order_id}\n📦 Статус: очікує", reply_markup=main_kb)

    # Отправляем в админ-бот
    msg_text = f"🛍 НОВЕ ЗАМОВЛЕННЯ\n🆔 {order_id}\n{ext}\n👤 {data['name']}\n📞 {data['phone']}\n🏠 {msg.text}\n💳 {data['payment']}"
    url = f"https://api.telegram.org/bot{ADMIN_BOT_TOKEN}/sendMessage"
    requests.post(url, json={
        "chat_id": ADMIN_CHAT_ID,
        "text": msg_text
    })

    await state.finish()

@dp.message_handler(lambda m: m.text == "📦 Мої замовлення")
async def my_orders(msg: types.Message):
    user_id = msg.from_user.id
    user_orders = orders.get(user_id, [])
    if not user_orders:
        await msg.answer("У вас ще немає замовлень.")
        return
    text = ""
    for i, o in enumerate(user_orders):
        items = "\n".join(f"— {item}" for item in o['items'])
        text += f"🛍 Замовлення №{user_id}-{i+1}\n{items}\n💳 {o['payment']}\n📦 Статус: *{o['status']}*\n\n"
    await msg.answer(text, parse_mode="Markdown")

@dp.message_handler(lambda m: m.text == "➕ Додати ще")
async def add_more(msg: types.Message):
    kb = ReplyKeyboardMarkup(resize_keyboard=True)
    for cat in menu:
        kb.add(cat)
    kb.add("🔙 Назад")
    await msg.answer("Обери категорію:", reply_markup=kb)

@dp.message_handler(lambda m: m.text == "🛒 Перейти до кошика")
async def go_to_cart(msg: types.Message):
    user_id = msg.from_user.id
    items = cart.get(user_id, [])
    if not items:
        await msg.answer("Кошик порожній 🧺")
        return
    text = "\n".join(f"{i+1}. {item}" for i, item in enumerate(items))
    await msg.answer(f"🛒 Ваш кошик:\n{text}\n\nОформити: /order")

@dp.message_handler(lambda m: m.text.startswith("/set_"))
async def select_status(msg: types.Message):
    # Адмінська команда — можна додати перевірку, якщо хочеш
    pass

@dp.message_handler(lambda m: m.text == "🔙 Назад")
async def back(msg: types.Message):
    await msg.answer("Обери опцію нижче:", reply_markup=main_kb)

if __name__ == '__main__':
    from aiogram import executor
    executor.start_polling(dp, skip_updates=True)
