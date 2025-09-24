from __future__ import annotations

from enum import Enum
from typing import Iterable

from pydantic import BaseModel, Field

__all__ = ["IAPProductType", "IAPProduct", "IAPCatalog"]


class IAPProductType(str, Enum):
    AUTO_RENEWABLE_SUBSCRIPTION = "auto_renewable_subscription"
    NON_CONSUMABLE = "non_consumable"
    CONSUMABLE = "consumable"


class IAPProduct(BaseModel):
    identifier: str = Field(alias="id")
    type: IAPProductType
    display_name: str = Field(alias="displayName")
    description: str
    duration: str | None = None
    entitlements: tuple[str, ...] = Field(default_factory=tuple)

    model_config = {
        "populate_by_name": True,
        "frozen": True,
    }

    def grants(self, entitlement: str) -> bool:
        return entitlement in self.entitlements


class IAPCatalog(BaseModel):
    products: tuple[IAPProduct, ...]

    model_config = {
        "populate_by_name": True,
        "frozen": True,
    }

    def product_ids(self) -> set[str]:
        return {product.identifier for product in self.products}

    def find(self, identifier: str) -> IAPProduct | None:
        for product in self.products:
            if product.identifier == identifier:
                return product
        return None

    def entitlements_for(self, identifier: str) -> tuple[str, ...]:
        product = self.find(identifier)
        if product is None:
            return ()
        return product.entitlements

    def subscription_products(self) -> tuple[IAPProduct, ...]:
        return tuple(
            product
            for product in self.products
            if product.type == IAPProductType.AUTO_RENEWABLE_SUBSCRIPTION
        )

    def require(self, identifier: str) -> IAPProduct:
        product = self.find(identifier)
        if product is None:
            raise KeyError(identifier)
        return product

    def as_list(self) -> list[IAPProduct]:
        return list(self.products)

    @classmethod
    def from_products(cls, products: Iterable[IAPProduct]) -> "IAPCatalog":
        return cls(products=tuple(products))
